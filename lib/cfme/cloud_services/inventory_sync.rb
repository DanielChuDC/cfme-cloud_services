module Cfme
  module CloudServices
    class InventorySync
      def self.sync(targets)
        targets = targets_from_queue(targets)

        ManifestFetcher.fetch do |manifest|
          DataCollector.collect(manifest, targets) do |payload|
            DataPackager.package(payload) do |payload_path|
              DataUploader.upload(payload_path)
            end
          end
        end
      end

      def self.sync_queue(userid, targets)
        task_opts = {
          :action => "Collect and upload inventory to cloud.redhat.com",
          :userid => userid
        }

        queue_opts = {
          :class_name  => self.name,
          :method_name => "sync",
          :role        => "internet_connectivity",
          :args        => [targets_for_queue(targets)]
        }

        MiqTask.generic_action_with_callback(task_opts, queue_opts)
      end

      def self.bundle(manifest:, targets:, tempdir: nil, perm: nil, task_id: nil, miq_task_id: nil)
        path = DataPackager.package(DataCollector.collect(manifest, targets_from_queue(targets)), tempdir, perm)
        update_task(task_id, path.to_s) if task_id
        path
      end

      def self.bundle_queue(userid, manifest, targets, tempdir = nil, perm = nil)
        task_opts = {
          :action => "Collect and package inventory",
          :userid => userid
        }

        args = {:manifest => manifest, :targets => targets_for_queue(targets), :tempdir => tempdir, :perm => perm}

        queue_opts = {
          :class_name  => name,
          :method_name => "bundle",
          :args        => [args]
        }

        MiqTask.generic_action_with_callback(task_opts, queue_opts)
      end

      private_class_method def self.targets_for_queue(targets)
        # Handle someone passing in a single instance, an array of instances,
        # an array of [class_name, id] pairs, or a mixture of instances and
        # [class_name, id] pairs, and "core"
        targets = Array(targets) unless targets.kind_of?(Array)
        targets.map do |klass_or_instance, id|
          if id.nil?
            if klass_or_instance.kind_of?(ActiveRecord::Base)
              instance = klass_or_instance
              [instance.class.name, instance.id]
            else
              klass_or_instance
            end
          else
            klass = klass_or_instance.to_s
            [klass, id]
          end
        end
      end

      private_class_method def self.targets_from_queue(targets)
        targets = Array(targets) unless targets.kind_of?(Array)
        targets.map do |klass_or_instance, id|
          id.nil? ? klass_or_instance : klass_or_instance.to_s.constantize.find(id)
        end
      end

      private_class_method def self.update_task(task_id, path)
        task = MiqTask.find(task_id)
        task.context_data ||= {}
        task.context_data[:payload_path] = path
        task.save!
      end
    end
  end
end
