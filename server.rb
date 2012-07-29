require "sinatra"
require "json"
require "aws-sdk"
require "yaml"

#This is for Foreman can properly get the output.
$stdout.sync = true

configure do
	#To load the configuration file
	CONFIG = YAML.load_file("config.yml") unless defined? CONFIG
	AWS.config(:access_key_id => CONFIG['access_key_id'], :secret_access_key => CONFIG['secret_access_key'])
	set :domains, CONFIG['swf_domains']
end

get "/" do
	redirect '/index.html'
end

post "/sandwich" do
	content_type :json
	puts JSON.parse(params[:order])
	swf = AWS::SimpleWorkflow.new
	domain = swf.domains[settings.domains]
	workflow_type = domain.workflow_types['Make Sandwich', '1']
	execution = workflow_type.start_execution(:input => params[:order])
  	return {:status => "OK"}.to_json
end
