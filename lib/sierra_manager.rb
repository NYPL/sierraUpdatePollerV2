require "date"
require "nypl_ruby_util"
require "uri"

require_relative "sierra_record"

# Manager for handling retrieval of records from the Sierra API
class SierraManager
  attr_accessor :processing, :records_processed
  attr_reader :current_time, :sierra_client, :state

  @@request_batch_size = 50

  # Set state object and other attributes necessary for processing records
  # Also constructs a sierra_client object
  def initialize(state)
    @state = state
    @processing = true
    @records_processed = { success: 0, error: 0 }
    @sierra_client = NYPLRubyUtil::SierraApiClient.new(
      client_id: $kms_client.decrypt(ENV["SIERRA_OAUTH_ID"]),
      client_secret: $kms_client.decrypt(ENV["SIERRA_OAUTH_SECRET"])
    )
  end

  # Fetch records in batches from the Sierra API
  # This will process batches in a loop until @processing is false
  def fetch_updated_records
    # This sets the end fetch time for the current invocation and will be the start_time for the next invocation
    @current_time = DateTime.now.to_s
    $logger.info "Setting fetch (end) time to #{@current_time}"

    # Fetch batches of records until no more remain to process
    while @processing
      results = _fetch_record_batch
      _parse_result_batch(results)
    end
  end

  def validate_processing
    $logger.info "Processed #{@records_processed[:success]} successfully and #{@records_processed[:error]} with errors"
    total_processed = @records_processed[:success] + @records_processed[:error]
    if @records_processed[:error] / total_processed.to_f >= 0.01
      $logger.error "Received too many errors as percentage of records processed", @records_processed
      raise SierraError, "Records processing errors exceeded 1% threshold!"
    end
  end

  private

  # Fetches an individual record batch from Sierra
  def _fetch_record_batch
    # Set up the GET request params
    update_date_str = "[#{@state.start_time},#{@current_time}]"
    param_array = [["fields", ENV["RECORD_FIELDS"]], ["offset", @state.start_offset],
                   ["updatedDate", update_date_str]]

    # Make query against Sierra API
    _query_sierra_api(param_array)
  end

  # Process a fetched batch of records
  def _parse_result_batch(results)
    if results.error?
      # If the Sierra API returned an error, check if the error is a 404
      # If so the response is empty and this is complete, if not raise and retry
      _process_error(results)
    else
      # Extract records from a successful request, validate and send to Kinesis
      _process_batch(results)
    end
  end

  # Construct and execute a query against the Sierra API
  def _query_sierra_api(param_array)
    # Encode request params
    param_str = URI.encode_www_form(param_array)
    $logger.debug("Querying Sierra API with params #{param_str}")

    # Execute request and handle errors
    begin
      result = @sierra_client.get("/#{ENV['SIERRA_VERSION']}/#{ENV['RECORD_TYPE']}?#{param_str}")
    rescue Exception => e
      $logger.error("Failed to query Sierra API", { status: e.message })
      raise SierraError, "Received error from Sierra API. Review logs"
    end

    result
  end

  # Process batch of records
  def _process_batch(results)
    # Extract relevant fields
    sierra_batch = SierraBatch.new(results)

    # Process records received
    sierra_batch.encode_and_send_to_kinesis

    # Update counts of total records processed
    _update_processing_counts sierra_batch.process_statuses

    # If we received fewer records than the maximum per batch this is the last batch
    # and we should set the state to start from this point and exit this invocation
    # else we should fetch and process the next batch
    if sierra_batch.size < @@request_batch_size
      @state.set_current_state(@current_time, 0)
      @processing = false
    else
      @state.set_current_state(@state.start_time, @state.start_offset + @@request_batch_size)
    end
  end

  # Process errors if received from the Sierra API
  def _process_error(results)
    # A 404 indicates an empty response, which is a valid case and should be treated as the end
    # of this invocation. Other error codes >=400 should be treated as exceptions.
    if results.code == 404
      $logger.info "No results received. Processing complete"
      @state.set_current_state(@current_time, 0)
      @processing = false
    else
      $logger.error "Received unexpected response from Sierra API", { status: results.body }
      raise SierraError, "Received unexpected #{results.code} from Sierra API"
    end
  end

  def _update_processing_counts(batch_counts)
    $logger.debug "Processed #{batch_counts[:success]} records successfully in batch"
    @records_processed[:success] += batch_counts[:success]

    $logger.debug "Errored on #{batch_counts[:error]} records in batch"
    @records_processed[:error] += batch_counts[:error]
  end
end

class SierraError < StandardError; end
