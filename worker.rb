require 'rubygems'
require "aws-sdk"
require "json"
require "yaml"

#To load the configuration file
CONFIG = YAML.load_file("config.yml") unless defined? CONFIG

#This is for Foreman can properly get the output.
$stdout.sync = true

AWS.config(:access_key_id => CONFIG['access_key_id'], :secret_access_key => CONFIG['secret_access_key'])
swf = AWS::SimpleWorkflow.new
domain = swf.domains[CONFIG['swf_domains']]


domain.activity_tasks.poll(CONFIG['swf_task_list']) do |activity_task|

  input = JSON.parse(activity_task.input)

  case activity_task.activity_type.name
    when 'Get-bread'
      puts "Getting #{input['bread']} for #{input['name']}'s sandwich"
      activity_task.complete!
    when 'Add-spread'
      puts "Getting #{input['spread']} for #{input['name']}'s sandwich"
      activity_task.complete!
    when 'Add-fillings'
      input['fillings'].each do |fill|
        puts "Adding #{fill} to #{input['name']}'s sandwich"
        activity_task.record_heartbeat! :details => "Added #{fill}"
        sleep(3.0)
      end
      activity_task.complete!
    when 'toasted'
      puts "Starting to toast #{input['name']}'s sandwich"
      10.times do |t|
        sleep(5.0)
        puts "#{input['name']}'s sandwich is #{10 * (t+1)}% toasted"
        activity_task.record_heartbeat! :details => "#{10 * (t+1)}%"
      end
      activity_task.complete!
  else
    activity_task.fail! :reason => 'unknown activity task type'
  end

end