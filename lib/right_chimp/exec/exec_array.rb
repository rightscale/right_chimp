#
# Run a RightScript on an array
#
module Chimp
  class ExecArray < Executor
    def run
      run_with_retry do
        options = @inputs

        if @timeout < 300
          Log.error 'timeout was less than 5 minutes! resetting to 5 minutes'
          @timeout = 300
        end

        audit_entry = @array.run_script_on_instances(@exec, @server['href'], options)

        if audit_entry
          audit_entry.each do |a|
            a.wait_for_completed('no audit link available', @timeout)
          end
        else
          Log.warn "No audit entries returned for job_id=#{@job_id}"
        end
      end
    end

    def describe_work
      "ExecArray job_id=#{@job_id} script=\"#{@exec['right_script']['name']}\" server=\"#{@server['nickname']}\""
    end

    def info
      @exec['right_script']['name']
    end

    def target
      @server['nickname']
    end
  end
end
