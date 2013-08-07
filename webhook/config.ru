require 'json'
require 'yaml'

def is_master_commit_push?(payload)
  payload["ref"] == "refs/heads/master"
end

def is_tag_push?(payload)
  payload["ref"] && payload["ref"] =~ /^refs\/tags\// && payload["created"]
end

def extract_tag_name(payload)
  payload["ref"].sub(/^ref\/tags\//, '')
end

def find_project(payload)
  repo_name = payload["repository"]["name"]
  projects = YAML.load_file("projects.yml")
  projects[repo_name]
end

def schedule_build(project, tag_name = nil)
  command = "/tools/silence-unless-failed chpst -l /tmp/passenger_autobuilder.lock " +
    "./autobuild-with-pbuilder #{project['git_url']} #{project['name']}"
  if tag_name
    command << " --tag=#{tag_name}"
  end
  puts "Executing command: #{command}"
  IO.popen("at now", "w") do |f|
    f.puts("cd /srv/passenger_autobuilder/app")
    f.puts(command)
  end
  true
end

def process_request(request, payload)
  if is_master_commit_push?(payload)
    if project = find_project(payload)
      schedule_build(project)
    else
      false
    end
  elsif is_tag_push?(payload) && (tag_name = extract_tag_name(payload))
    if project = find_project(payload)
      schedule_build(project, tag_name)
    else
      false
    end
  else
    false
  end
end

app = lambda do |env|
  request = Rack::Request.new(env)
  payload = JSON.parse(request.params["payload"])
  if process_request(request, payload)
    [200, { "Content-Type" => "text/plain" }, ["ok"]]
  else
    [500, { "Content-Type" => "text/plain" }, ["Internal server error"]]
  end
end

run app
