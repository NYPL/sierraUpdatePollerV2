require "bundler/setup"
require "nypl_ruby_util"

require_relative "lib/state_manager"
require_relative "lib/sierra_manager"

def init
  $logger = NYPLRubyUtil::NyplLogFormatter.new(STDOUT, level: ENV["LOG_LEVEL"])
  $kms_client = NYPLRubyUtil::KmsClient.new
  $kinesis_client = NYPLRubyUtil::KinesisClient.new({
    schema_string: ENV["SCHEMA_TYPE"],
    stream_name: ENV["KINESIS_STREAM"],
    partition_key: "id"
    # put batch size in here to match @@request_batch_size = 50 in sierra_manager.rb line 12?
  })

  $logger.debug "Initialized function"
end

def handle_event(event:, context:)
  init

  # Fetch current state from S3
  $logger.info "Loading State from s3"
  state = StateManager.new
  state.fetch_current_state

  # Load records given current starting position in state
  $logger.info "Fetching information from Sierra API"
  sierra = SierraManager.new(state)
  sierra.fetch_updated_records
  sierra.validate_processing

  $logger.info "Processing Complete"
end
