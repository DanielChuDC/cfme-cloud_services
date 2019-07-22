module Api
  class RedHatCloudServiceProvidersController < BaseController
    def red_hat_cloud_service_providers_search_conditions
      { :type => provider_types }
    end

    def find_red_hat_cloud_service_providers(id)
      collection_type = :red_hat_cloud_service_providers
      klass = collection_class(collection_type)
      provider = find_resource(klass, "id", id)
      provider = filter_resource(provider, collection_type, klass)
      raise NotFoundError, "Invalid Provider id:#{id} specified" unless provider_types.include?(provider.type)

      provider
    end

    def sync_resource(_type, id, _data)
      provider = find_red_hat_cloud_service_providers(id)
      desc = "Syncing #{provider_ident(provider)}"
      task_id = Cfme::CloudServices::InventorySync.sync_queue(User.current_user.userid, provider)
      action_result(true, desc, :task_id => task_id)
    rescue => e
      action_result(false, e.to_s)
    end

    private

    def provider_ident(provider)
      "Provider id:#{provider.id} name:'#{provider.name}'"
    end

    def provider_types
      manifest = Cfme::CloudServices::ManifestFetcher.fetch["manifest"] || {}
      manifest.keys.reject { |k| k == "core" }.uniq
    end
  end
end
