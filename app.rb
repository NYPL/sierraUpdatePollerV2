require 'bundler/setup'
require 'nypl_ruby_util'

require_relative 'lib/state_manager'
require_relative 'lib/sierra_manager'

def init
    $logger = NYPLRubyUtil::NyplLogFormatter.new(STDOUT, level: ENV['LOG_LEVEL'])
    $kms_client = NYPLRubyUtil::KmsClient.new
    $kinesis_client = NYPLRubyUtil::KinesisClient.new({
        :schema_string => ENV['SCHEMA_TYPE'],
        :stream_name => ENV['KINESIS_STREAM'],
        :partition_key => 'id' }
    )

    $logger.debug "Initialized function"
end

def handle_event(event:, context:)
    init

    # If processing a manual job, create a job-specific state manager:
    if event['manual_job']
        $logger.info "Processing manual job: #{event.to_json}"
        state = create_manual_job_state_manager event
    else
        # Fetch current state from S3
        $logger.info "Loading State from s3"
        state = StateManager.new
        state.fetch_current_state
    end

    # Load records given current starting position in state
    $logger.info "Fetching information from Sierra API"
    sierra = SierraManager.new(state)
    sierra.fetch_updated_records
    sierra.validate_processing

    $logger.info "Processing Complete"
end

##
# Create a state manager to handle a single one-off update job
def create_manual_job_state_manager(event)
    Class.new do
        def initialize(event)
            @event = event
        end

        def start_time
            @event['start_time']
        end

        def end_time
            @event['end_time']
        end

        def start_offset
            @event['start_offset']
        end

        def set_current_state(execution_time, execution_offset); end
    end.new event
end
