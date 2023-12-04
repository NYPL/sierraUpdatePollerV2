require "bundler/setup"
require "nypl_ruby_util"

require_relative 'lib/state_manager'
require_relative 'lib/manual_job_state_manager'
require_relative 'lib/sierra_manager'

def init
  ENV["AWS_SESSION_TOKEN"] = nil if ENV["AWS_SAM_LOCAL"]
  $logger = NYPLRubyUtil::NyplLogFormatter.new(STDOUT, level: ENV["LOG_LEVEL"])
  $kms_client = NYPLRubyUtil::KmsClient.new
  $kinesis_client = NYPLRubyUtil::KinesisClient.new({
    schema_string: ENV["SCHEMA_TYPE"],
    stream_name: ENV["KINESIS_STREAM"],
    partition_key: "id",
    # As of right now, we want to ensure that the sierra request batch size and the kinesis batch sizes are equal in order to avoid losing records in the case of a timeout.
    batch_size: (ENV["REQUEST_BATCH_SIZE"] || 50).to_i
  })

  $logger.debug "Initialized function"
end

def handle_event(event:, context:)
  init

  # If processing a manual job, create a job-specific state manager:
  if event['manual_job']
      $logger.info "Processing manual job: #{event.to_json}"
      state = ManualJobStateManager.new event
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
