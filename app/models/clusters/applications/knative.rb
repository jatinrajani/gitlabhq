# frozen_string_literal: true

module Clusters
  module Applications
    class Knative < ApplicationRecord
      VERSION = '0.6.0'
      REPOSITORY = 'https://storage.googleapis.com/triggermesh-charts'
      METRICS_CONFIG = 'https://storage.googleapis.com/triggermesh-charts/istio-metrics.yaml'
      FETCH_IP_ADDRESS_DELAY = 30.seconds
      API_RESOURCES_PATH = 'config/knative/api_resources.yml'

      self.table_name = 'clusters_applications_knative'

      include ::Clusters::Concerns::ApplicationCore
      include ::Clusters::Concerns::ApplicationStatus
      include ::Clusters::Concerns::ApplicationVersion
      include ::Clusters::Concerns::ApplicationData
      include AfterCommitQueue

      def set_initial_status
        return unless not_installable?
        return unless verify_cluster?

        self.status = status_states[:installable]
      end

      state_machine :status do
        after_transition any => [:installed] do |application|
          application.run_after_commit do
            ClusterWaitForIngressIpAddressWorker.perform_in(
              FETCH_IP_ADDRESS_DELAY, application.name, application.id)
          end
        end
      end

      default_value_for :version, VERSION

      validates :hostname, presence: true, hostname: true

      scope :for_cluster, -> (cluster) { where(cluster: cluster) }

      def chart
        'knative/knative'
      end

      def values
        { "domain" => hostname }.to_yaml
      end

      def allowed_to_uninstall?
        !pre_installed?
      end

      def install_command
        Gitlab::Kubernetes::Helm::InstallCommand.new(
          name: name,
          version: VERSION,
          rbac: cluster.platform_kubernetes_rbac?,
          chart: chart,
          files: files,
          repository: REPOSITORY,
          postinstall: install_knative_metrics
        )
      end

      def schedule_status_update
        return unless installed?
        return if external_ip
        return if external_hostname

        ClusterWaitForIngressIpAddressWorker.perform_async(name, id)
      end

      def ingress_service
        cluster.kubeclient.get_service('istio-ingressgateway', 'istio-system')
      end

      def uninstall_command
        Gitlab::Kubernetes::Helm::DeleteCommand.new(
          name: name,
          rbac: cluster.platform_kubernetes_rbac?,
          files: files,
          predelete: delete_knative_services_and_metrics,
          postdelete: delete_knative_istio_leftovers
        )
      end

      private

      def delete_knative_services_and_metrics
        delete_knative_services + delete_knative_istio_metrics
      end

      def delete_knative_services
        cluster.kubernetes_namespaces.map do |kubernetes_namespace|
          Gitlab::Kubernetes::KubectlCmd.delete("ksvc", "--all", "-n", kubernetes_namespace.namespace)
        end
      end

      def delete_knative_istio_leftovers
        delete_knative_namespaces + delete_knative_and_istio_crds
      end

      def delete_knative_namespaces
        [
          Gitlab::Kubernetes::KubectlCmd.delete("--ignore-not-found", "ns", "knative-serving"),
          Gitlab::Kubernetes::KubectlCmd.delete("--ignore-not-found", "ns", "knative-build")
        ]
      end

      def delete_knative_and_istio_crds
        api_resources.map do |crd|
          Gitlab::Kubernetes::KubectlCmd.delete("--ignore-not-found", "crd", "#{crd}")
        end
      end

      # returns an array of CRDs to be postdelete since helm does not
      # manage the CRDs it creates.
      def api_resources
        @api_resources ||= YAML.safe_load(File.read(Rails.root.join(API_RESOURCES_PATH)))
      end

      def install_knative_metrics
        return [] unless cluster.application_prometheus_available?

        [Gitlab::Kubernetes::KubectlCmd.apply_file(METRICS_CONFIG)]
      end

      def delete_knative_istio_metrics
        return [] unless cluster.application_prometheus_available?

        [Gitlab::Kubernetes::KubectlCmd.delete("--ignore-not-found", "-f", METRICS_CONFIG)]
      end

      def verify_cluster?
        cluster&.application_helm_available? && cluster&.platform_kubernetes_rbac?
      end
    end
  end
end
