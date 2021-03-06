#
# QueueWorker objects take work from the Queue and process it
# Each QueueWorker runs in its own thread... nothing fancy going on here
#
module Chimp
  class QueueWorker
    attr_accessor :delay, :retry_count, :never_exit

    def initialize
      @delay = 0
      @retry_count = 0
      @never_exit = true
    end

    #
    # Grab work items from the ChimpQueue and process them
    # Only stop is @ever_exit is false
    #
    def run
      while @never_exit
        work_item = ChimpQueue.instance.shift()

        begin
          if work_item != nil

            job_uuid = work_item.job_uuid
            group = work_item.group.group_id

            work_item.retry_count = @retry_count
            work_item.owner = Thread.current.object_id

            ChimpDaemon.instance.semaphore.synchronize do
              # only do this if we are running with chimpd
              if ChimpDaemon.instance.queue.processing[group].nil?
                # no op
              else
                # remove from the processing queue
                if ChimpDaemon.instance.queue.processing[group][job_uuid.to_sym] == 0
                  Log.debug 'Completed processing task ' + job_uuid.to_s
                  Log.debug 'Deleting ' + job_uuid.to_s

                  ChimpDaemon.instance.queue.processing[group].delete(job_uuid.to_sym)

                  Log.debug ChimpDaemon.instance.queue.processing.inspect

                  ChimpDaemon.instance.proc_counter -= 1
                else
                  if ChimpDaemon.instance.queue.processing[group][job_uuid.to_sym].nil?
                    Log.debug 'Job group was already deleted, no counter to decrease.'
                  else
                    Log.debug 'Decreasing processing counter (' + ChimpDaemon.instance.proc_counter.to_s +
                              ') for [' + job_uuid.to_s + '] group: ' + group.to_s

                    ChimpDaemon.instance.queue.processing[group][job_uuid.to_sym] -= 1

                    Log.debug 'Processing counter now (' + ChimpDaemon.instance.proc_counter.to_s +
                              ') for [' + job_uuid.to_s + '] group: ' + group.to_s
                    Log.debug ChimpDaemon.instance.queue.processing[group].inspect
                    Log.debug 'Still counting down for ' + job_uuid.to_s

                    ChimpDaemon.instance.proc_counter -= 1
                  end
                end
              end
            end

            work_item.run
          else
            sleep 1
          end

        rescue Exception => ex
          Log.error "Exception in QueueWorker.run: #{ex}"
          Log.debug ex.inspect
          Log.debug ex.backtrace

          work_item.status = Executor::STATUS_ERROR
          work_item.error = ex
        end
      end
    end

  end
end
