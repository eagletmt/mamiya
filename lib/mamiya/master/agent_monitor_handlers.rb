require 'mamiya/master'

module Mamiya
  class Master
    # XXX: TODO:
    module AgentMonitorHandlers
      def task__start(status, payload, event)
        task = payload['task']

        status['queues'] ||= {}
        status['queues'][task['task']] ||= {'queue' => [], 'working' => nil}

        status['queues'][task['task']]['working'] = task
        status['queues'][task['task']]['queue'].delete task
      end

      def task__finalize(status, payload, event)
        task = payload['task']

        status['queues'] ||= {}
        status['queues'][task['task']] ||= {'queue' => [], 'working' => nil}

        s = status['queues'][task['task']]
        if s['working'] == task
          s['working'] = nil
        end
        status['queues'][task['task']]['queue'].delete task
      end

      def task__finish(status, payload, event)
        task = payload['task']
        logger.info "#{status['name']} has finished task #{task['task'].inspect}"

        task__finalize(status, payload, event)

        method_name = "task___#{task['task']}__finish"
        if self.respond_to?(method_name)
          __send__ method_name, status, task
        end
      end

      def task__error(status, payload, event)
        task = payload['task']
        logger.error "#{status['name']} has failed task #{task['task'].inspect}: #{payload['error']}"

        task__finalize(status, payload, event)

        method_name = "task___#{task['task']}__error"
        if self.respond_to?(method_name)
          __send__ method_name, status, task, error
        end
      end



      # XXX: move task finish handlers into tasks/
      def task___fetch__finish(status, task)
        status['packages'] ||= {}
        status['packages'][task['app']] ||= []

        unless status['packages'][task['app']].include?(task['pkg'])
          status['packages'][task['app']] << task['pkg']
        end
      end

      def task___prepare__finish(status, task)
        status['prereleases'] ||= {}
        status['prereleases'][task['app']] ||= []

        unless status['prereleases'][task['app']].include?(task['pkg'])
          status['prereleases'][task['app']] << task['pkg']
        end
      end

      def task___switch__finish(status, task)
        status['currents'] ||= {}
        status['currents'][task['app']] = task['pkg']

        status['releases'] ||= {}
        status['releases'][task['app']] ||= []
        status['releases'][task['app']].push task['pkg']
        status['releases'][task['app']].uniq!
      end

      def task___remove__finish(status, task)
        refresh # ThreadError: deadlock; recursive locking
      end

      def pkg__remove(status, payload, event)
        status['packages'] ||= {}
        packages = status['packages'][payload['application']]
        packages.delete(payload['package']) if packages
      end

      def prerelease__remove(status, payload, event)
        status['prereleases'] ||= {}
        prereleases = status['prereleases'][payload['app']]
        prereleases.delete(payload['pkg']) if prereleases
      end

      def release__remove(status, payload, event)
        status['releases'] ||= {}
        releases = status['releases'][payload['app']]
        releases.delete(payload['pkg']) if releases
      end
    end
  end
end
