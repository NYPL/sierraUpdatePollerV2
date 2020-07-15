require 'aws-sdk-s3'
require 'date'
require 'json'
require 'net/https'
require 'uri'


# Class for managing the state of the poller in S3
class StateManager
    attr_reader :start_time, :start_offset

    # Create S3 client
    def initialize
       @s3 = Aws::S3::Client.new(region: ENV['AWS_REGION'])
    end

    # Load current state from S3 object, sets two attributes
    # start_time: The start time of the last successful batch fetch 
    # start_offset: The offset for the last successful batch fetch
    def fetch_current_state
        # Fetch JSON object from S3
        begin
            status_uri = URI("#{ENV['NYPL_CORE_S3_BASE_URL']}/#{ENV['BUCKET_NAME']}/#{ENV['RECORD_TYPE']}_poller_status.json")
            $logger.debug "Fetching state from #{status_uri}"
            response = Net::HTTP.get_response(status_uri)
        rescue Exception => e
            $logger.error "Failed to load state file from S3", { :status => e.message }
            raise S3Error.new("Could not load file from S3")
        end
        
        # Confirm that a valid response was received
        unless response.code.to_i == 200 
            $logger.error "Unable to load state from S3", { :status => response.body }
            raise S3Error.new("Unable to load state from S3 with error #{response.body}")
        end

        # Parse response into an object
        status_body = JSON.parse(response.body)

        # Validate that retrieved object corresponds to the correct record type
        unless status_body['record_type'] == ENV['RECORD_TYPE']
            $logger.error "Loaded incorrect record (#{status_body['record_type']}) from S3"
            raise S3Error.new("Loaded JSON file for incorrect record type")
        end

        # Set attributes as received from S3 object
        @start_time = status_body['last_execution_time']
        @start_offset = status_body['last_execution_offset']
        $logger.debug "Fetched state START_TIME: #{@start_time}, START_OFFSET: #{@start_offset}"
    end
        
    # Set new state values for execution time and offset. Invoked upon succesful parsing of a batch
    def set_current_state(execution_time, execution_offset)
        $logger.debug "Setting state from last fetch execution EXECUTION_TIME: #{execution_time}, EXECUTION_OFFSET: #{execution_offset}"

        # Create a JSON object
        json_body = JSON.dump({
            :last_execution_time => execution_time,
            :last_execution_offset => execution_offset,
            :record_type => ENV['RECORD_TYPE']
        })

        # Send object to S3.
        # If this fails the function errors and records are retried from the previous position
        begin
            resp = @s3.put_object({
                :body => json_body,
                :bucket => ENV['BUCKET_NAME'],
                :key => "#{ENV['RECORD_TYPE']}_poller_status.json",
                :acl => "public-read"
            })
        rescue Exception => e
            $logger.error "Unable to store current state record in S3", { :status => e.message } 
            raise S3Error.new("Failed to store most recent state record in S3")
        end

        # Set new state for use in processing subsequent batches within this invocation
        @start_time = execution_time
        @start_offset = execution_offset
    end
end


class S3Error < StandardError; end