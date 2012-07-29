require 'rubygems'
require "aws-sdk"
require "yaml"

#To load the configuration file
CONFIG = YAML.load_file("config.yml") unless defined? CONFIG

#This is for Foreman can properly get the output.
$stdout.sync = true

AWS.config(:access_key_id => CONFIG['access_key_id'], :secret_access_key => CONFIG['secret_access_key'])
swf = AWS::SimpleWorkflow.new
domain = swf.domains[CONFIG['swf_domains']]

#Used to figure out what has happened completed.
def done_task(events)
	ids = []
	task = []
	events.each do |e|
		if e.to_h[:event_type] == 'ActivityTaskCompleted'
			ids << e.to_h[:attributes][:scheduled_event_id]
		elsif e.to_h[:event_type] == 'ActivityTaskScheduled' && ids.include?(e.to_h[:event_id])
			task << e.to_h[:attributes][:activity_type].name
		end
	end
	return task
end

#Used to get the original input sent from the Web server.
def getInput(events)
	events.each do |e|
		if e.to_h[:event_type] == 'WorkflowExecutionStarted'
			return e.to_h[:attributes][:input]
		end
	end
	return ""
end


domain.decision_tasks.poll(CONFIG['swf_task_list']) do |task|
	events_list = task.workflow_execution.events.reverse_order
	done_task_list = done_task(events_list)
	input_json = getInput(events_list)
	begin
		input = JSON.parse(input_json)
	rescue
    	task.cancel_workflow_execution
    	next
  	end

	if !done_task_list.include?("Get-bread")
		orderText = "Starting new order for #{input['name']}, a #{input['fillings'].join(', ')} on #{input['bread']}"
		if input['spread'] != "None"
			orderText += " with #{input['spread']}"
		end
		if input['toasted'] == "true"
			orderText += " toasted"
		end
		puts orderText
		task.schedule_activity_task domain.activity_types['Get-bread', '1'], :input => input_json
	elsif input['spread'] != "None" && done_task_list.include?("Get-bread") && !done_task_list.include?("Add-spread")
		task.schedule_activity_task domain.activity_types['Add-spread', '1'], :input => input_json
	elsif !done_task_list.include?("Add-fillings")
		task.schedule_activity_task domain.activity_types['Add-fillings', '1'], :input => input_json
	elsif done_task_list.include?("Add-fillings") && !done_task_list.include?("toasted")
		if input['toasted'] == "true"
			task.schedule_activity_task domain.activity_types['toasted', '1'], :input => input_json
		else
			puts "#{input['name']}'s sandwich is made!"
			task.complete_workflow_execution
		end
	elsif done_task_list.include?("toasted")
		puts "#{input['name']}'s toasted sandwich is made!"
		task.complete_workflow_execution
	end
end
