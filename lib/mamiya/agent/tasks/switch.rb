require 'fileutils'

require 'mamiya/agent/tasks/notifyable'
require 'mamiya/steps/switch'

module Mamiya
  class Agent
    module Tasks
      class Switch < Notifyable
        class PrereleaseMissing < Exception; end

        def execute
          return unless check
          super
        end

        def check
          return true if prerelease_path.exist?
          return true if release_prepared?

          unless package_path.exist?
            new_chain = ['prepare', 'switch'] + (task['_chain'] || [])
            logger.info "Package not fetched, enqueueing fetch task with #{new_chain.inspect}"
            task_queue.enqueue(
              :fetch,
              task.merge('_chain' => new_chain)
            )
            return false
          end

          unless prerelease_path.exist?
            new_chain = ['switch'] + (task['_chain'] || [])
            logger.info "Package not prepared, enqueueing prepare task with #{new_chain.inspect}"
            task_queue.enqueue(
              :prepare,
              task.merge('_chain' => new_chain)
            )
            return false
          end

          true
        end

        def run
          case
          when prerelease_path.exist? && release_path.exist? && !release_path.join('.mamiya.prepared').exist?
            logger.info "Removing existing release (not prepared)"
            FileUtils.remove_entry_secure release_path
          when !prerelease_path.exist? && prelease_path.exist? && !release_path.join('.mamiya.prepared').exist?
            # this condition may be a bug
            logger.error "Existing release is not prepared but prerelease doesn't exist"
            raise PrereleaseMissing, "Existing release is not prepared but prerelease doesn't exist"
          end

          logger.info "Copying #{prerelease_path} -> #{release_path}"
          FileUtils.cp_r prerelease_path, release_path

          logger.info "Switching"
          switch_step.run!

          task_queue.enqueue(:clean, {})
        end

        private

        def application
          task['app']
        end

        def package
          task['pkg']
        end

        def release_name
          task['release'] || package
        end

        def packages_dir
          @packages_dir ||= config.packages_dir
        end

        def prereleases_dir
          @prereleases_dir ||= config.prereleases_dir
        end

        def package_path
          packages_dir.join(application, "#{package}.tar.gz")
        end

        def prerelease_path
          prereleases_dir.join(application, release_name)
        end

        def releases_dir
          config.deploy_to_for(application).join('releases').tap(&:mkpath)
        end

        def release_path
          releases_dir.join(release_name)
        end

        def release_prepared?
          release_path.exist? && release_path.join('.mamiya.prepared').exist?
        end

        def labels
          @labels ||= agent.labels
        end

        def switch_step
          @switch_step ||= Mamiya::Steps::Switch.new(
            target: release_path,
            config: config,
            logger: logger,
            config: config,
            labels: agent.labels,
            no_release: !!task['no_release']
          )
        end
      end
    end
  end
end
