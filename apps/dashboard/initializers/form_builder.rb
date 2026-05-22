require 'yaml'

class MSI
	class FormBuilder
		DEFAULT_CLUSTER    = ['agate'].freeze
		GPU_PARTITION_NAMES = %w[interactive-gpu preempt-gpu msigpu].freeze

		def self.quick_resources
			[
				# Format is partition:nodes:ntasks-per-node:memory:tmp:gpus
				['Interactive - 2 cores, 32 GB, 64 GB local scratch', 'interactive:1:2:32768:65536:0'],
				['Interactive Long - 2 cores, 32 GB, 64 GB local scratch', 'interactive-long:1:2:32768:65536:0'],
				['Interactive GPU - 16 cores, 60 GB, 100 GB local scratch, 1 GPU', 'interactive-gpu:1:16:61440:102400:1'],
				['Big Mem - 32 cores, 500 GB, 190 GB local scratch', 'ag2tb:1:32:512000:194560:0'],
			]
		end

		def self.partitions
			[
				'interactive',
				'interactive-gpu',
				'preempt',
				'preempt-gpu',
				'interactive-long',
				'msismall',
				'msilarge',
				'msilong',
				'msigpu',
				'msibigmem',
			]
		end

		def initialize(attributes:, overrides: {}, include_custom_environment_controls: false, include_cuda_version: false)
			@attributes = stringify_keys(attributes)
			@overrides = stringify_keys(overrides)
			@include_custom_environment_controls = include_custom_environment_controls
			@include_cuda_version = include_cuda_version
		end

		def to_h
			{
				'cluster' => DEFAULT_CLUSTER,
				'form' => generated_form,
				'attributes' => rendered_attributes,
			}
		end

		def render
			YAML.dump(to_h)
		end

		private

		def merged_attributes
			merged = deep_copy(common_attributes)

			@attributes.each do |key, value|
				base = common_attributes[key]

				merged[key] = if base.is_a?(Hash) && value.is_a?(Hash)
					deep_merge(base, value)
				elsif value.nil? && base
					base
				else
					value
				end
			end

			@overrides.each_key do |key|
				next if merged.key?(key)

				merged[key] = common_attributes[key] || {}
			end

			deep_merge(merged, @overrides)
		end

		def generated_form
			ordered_entries = merged_attributes.each_with_index.map do |(key, value), index|
				[key, value, index]
			end

			ordered_entries
				.sort_by { |(_key, value, index)| [priority_for(value), index] }
				.map { |(key, _value, _index)| key }
		end

		def rendered_attributes
			merged_attributes.each_with_object({}) do |(key, value), out|
				next unless value.is_a?(Hash)

				attribute = value.reject { |attr_key, _attr_value| attr_key == 'priority' }
				next if attribute.empty?

				out[key] = attribute
			end
		end

		def priority_for(value)
			return Float::INFINITY unless value.is_a?(Hash)

			priority = value['priority']
			return Float::INFINITY if priority.nil?

			priority.to_i
		end

		def common_attributes
			attributes = {
				'account' => account_attribute,
				'resources' => resources_attribute,
				'partitions' => partitions_attribute,
				'custom_partitions' => {
					'priority' => 70,
					'hide_by_default' => true,
					'widget' => 'text_field',
				},
				'nodes' => {
					'priority' => 80,
					'label' => 'Number of Nodes',
					'help' => "The number of nodes you'd like.",
					'widget' => 'number_field',
					'value' => 1,
				},
				'ntasks' => {
					'priority' => 90,
					'label' => 'Cores per Node',
					'help' => "The number of cores you'd like per node.",
					'widget' => 'number_field',
					'value' => 1,
				},
				'memory' => {
					'priority' => 100,
					'label' => 'Memory per Node',
					'help' => 'The amount of memory you would like per node. Slurm suffixes are supported, so you can enter values like "4G" or "8192M". Default unit is MiB.',
					'widget' => 'text_field',
					'value' => 8192,
				},
				'scratch' => {
					'priority' => 110,
					'label' => 'Scratch per Node',
					'help' => 'The amount of local scratch you would like per node. Slurm suffixes are supported, so you can enter values like "4G" or "8192M". Default unit is MiB.',
					'widget' => 'text_field',
				},
				# Shown only for the interactive-gpu partition (A40/L40s hardware).
				'gpu_model_interactive' => {
					'priority' => 120,
					'hide_by_default' => true,
					'label' => 'GPU Model',
					'help' => 'Choose the preferred GPU model for your job.',
					'widget' => 'select',
					'options' => [
						['Any', 'any'],
						['A40', 'a40'],
						['L40s', 'l40s'],
					],
				},
				# Shown for other GPU partitions (preempt-gpu, msigpu; V100/A100/H100 hardware).
				'gpu_model_other' => {
					'priority' => 122,
					'hide_by_default' => true,
					'label' => 'GPU Model',
					'help' => 'Choose the preferred GPU model for your job.',
					'widget' => 'select',
					'options' => [

						['Any', 'any'],
						['V100', 'v100'],
						['A100', 'a100'],
						['H100', 'h100'],
					],
				},
				# Shown for custom partitions — full set of all known GPU models.
				'gpu_model_custom' => {
					'priority' => 123,
					'hide_by_default' => true,
					'label' => 'GPU Model',
					'help' => 'Choose the preferred GPU model for your job.',
					'widget' => 'select',
					'options' => [

						['Any', 'any'],
						['A40',  'a40'],
						['L40s', 'l40s'],
						['V100', 'v100'],
						['A100', 'a100'],
						['H100', 'h100'],
					],
				},
				'gpus' => {
					'priority' => 130,
					'hide_by_default' => true,
					'label' => 'GPUs per Node',
					'help' => 'The number of GPUs you would like per node. Set to 0 for no GPU.',
					'widget' => 'number_field',
					'value' => 0,
				},
				'num_hours' => {
					'priority' => 980,
					'label' => 'Time Limit',
					'help' => 'Shorter times will probably start faster',
					'widget' => 'select',
					'options' => [
						['1 Hours', 1, { 'data-hide-custom-time' => true }],
						['4 Hours', 4, { 'data-hide-custom-time' => true }],
						['8 Hours', 8, { 'data-hide-custom-time' => true }],
						['24 Hours', 24, { 'data-hide-custom-time' => true }],
						['Custom', 0, { 'data-hide-custom-time' => false }],
						['Until Next Maintenance', -1, { 'data-hide-custom-time' => true }],
					],
				},
				'custom_time' => {
					'priority' => 990,
					'hide_by_default' => true,
					'label' => 'Custom Time Limit',
					'help' => 'How long you would like your job to run. You can enter time using Slurm\'s time format (e.g. "1-12" for 1 day and 12 hours, "12:00:00" for 12 hours).',
					'widget' => 'text_field',
				},
				'bc_email_on_started' => {
					'priority' => 999,
				},
			}

			if @include_custom_environment_controls
				attributes = attributes.merge({
					'customize' => {
						'priority' => 900,
						'label' => 'Customize Environment',
						'widget' => 'check_box',
						'value' => 0,
						'html_options' => {
							'data' => {
								'hide-custom-environment-when-not-checked' => true,
							},
						},
					},
					'custom_environment' => {
						'priority' => 901,
						'widget' => 'text_area',
						'label' => 'Custom Environment',
						'help' => 'Enter commands (module load, source activate, etc) to create your desired environment.',
						'value' => "module load xyz\n",
					},
				})
			end

			if @include_cuda_version
				attributes = attributes.merge({
					'cuda_version' => {
						'priority' => 140,
						'hide_by_default' => true,
						'widget' => 'select',
						'label' => 'CUDA Version',
						'help' => "CUDA is Nvidia's GPU-specific parallel computing framework. A GPU node\nis required to make use of this functionality.",
						'options' => [
							['cuda/10.0', 'cuda/10.0'],
							['cuda/10.1', 'cuda/10.1'],
							['cuda/11.2', 'cuda/11.2'],
							['cuda/12.0', 'cuda/12.0'],
						],
					},
				})
			end

			attributes
		end

		def account_attribute
			accounts = MSI.accounts
			if accounts.size > 0
				{
					'priority' => 50,
					'widget' => 'select',
					'options' => accounts,
				}
			else
				{
					'priority' => 50,
					'widget' => 'text_field',
					'help' => 'Unable to query accounts, please enter one manually. If left blank, your primary group will be used.',
				}
			end
		end

		def resources_attribute
			options = []
			hide_manual_resource_fields = {
				'data-hide-partitions'            => true,
				'data-hide-nodes'                 => true,
				'data-hide-ntasks'                => true,
				'data-hide-memory'                => true,
				'data-hide-scratch'               => true,
				'data-hide-gpus'                  => true,
				'data-hide-gpu-model-interactive' => true,
				'data-hide-gpu-model-other'       => true,
				'data-hide-gpu-model-custom'      => true,
				'data-hide-custom-partitions'     => true,
				'data-hide-cuda-version'          => true,
			}

			# When Custom is selected, show all manual resource fields.
			# Note: data-hide-gpus is overridden to false in the Custom option below.
			# GPU model fields remain hidden here; the partition selection reveals them.
			show_manual_resource_fields = {
				'data-hide-partitions'            => false,
				'data-hide-nodes'                 => false,
				'data-hide-ntasks'                => false,
				'data-hide-memory'                => false,
				'data-hide-scratch'               => false,
				'data-hide-gpus'                  => true,
				'data-hide-gpu-model-interactive' => true,
				'data-hide-gpu-model-other'       => true,
				'data-hide-gpu-model-custom'      => true,
				'data-hide-custom-partitions'     => true,
				'data-hide-cuda-version'          => true,
			}

			self.class.quick_resources.each do |resource|
				resource_parts = resource[1].split(':')
				resource_partition = resource_parts[0]
				gpus = resource_parts[5].to_i rescue 0
				data_attrs = hide_manual_resource_fields.dup
				if gpus > 0
					# Show gpu_model_interactive (interactive-gpu hardware: A40/L40s).
					# Gpus count is hidden — the preset value string fixes it at 1.
					data_attrs['data-hide-gpu-model-interactive'] = false
					data_attrs['data-hide-cuda-version'] = false
					# Keep partitions and resources in sync for browser-restored state.
					if self.class.partitions.include?(resource_partition)
						data_attrs['data-set-partitions'] = resource_partition
					end
				else
					# Reset partitions to a non-GPU value when a non-GPU preset is selected.
					# This ensures that stale cached GPU partition options do not reveal
					# gpu_model fields that should stay hidden for non-GPU presets.
					data_attrs['data-set-partitions'] = 'interactive'
				end
				options << [resource[0], resource[1], data_attrs]
			end

			# Custom: show all manual fields including gpus directly.
			# Gpus visibility is controlled here (not by partitions) so there is no
			# initialization-order race between resources and partitions selects.
			options << ['Custom', 'custom', show_manual_resource_fields.merge(
				'data-hide-gpus'      => false,
				'data-set-partitions' => 'interactive'
			)]

			{
				'priority' => 60,
				'widget' => 'select',
				'options' => options,
			}
		end

		def partitions_attribute
			options = []

			# Partition options control gpu_model_* and cuda_version visibility but
			# NOT gpus count — that is controlled solely by the resources select so
			# there is no initialization-order conflict when a stale cached GPU
			# partition is present while a non-GPU resource preset is active.
			self.class.partitions.each do |partition|
				if %w[interactive-gpu preempt-gpu].include?(partition)
					opts = {
						'data-hide-custom-partitions'     => true,
						'data-hide-gpu-model-interactive' => false,
						'data-hide-gpu-model-other'       => true,
						'data-hide-gpu-model-custom'      => true,
						'data-hide-cuda-version'          => false,
					}
				elsif GPU_PARTITION_NAMES.include?(partition)
					# msigpu
					opts = {
						'data-hide-custom-partitions'     => true,
						'data-hide-gpu-model-interactive' => true,
						'data-hide-gpu-model-other'       => false,
						'data-hide-gpu-model-custom'      => true,
						'data-hide-cuda-version'          => false,
					}
				else
					opts = {
						'data-hide-custom-partitions'     => true,
						'data-hide-gpu-model-interactive' => true,
						'data-hide-gpu-model-other'       => true,
						'data-hide-gpu-model-custom'      => true,
						'data-hide-cuda-version'          => true,
					}
				end
				options << [partition, partition, opts]
			end

			# Unknown custom partition — show the full combined GPU model list.
			options << ['Custom', 'custom', {
				'data-hide-custom-partitions'     => false,
				'data-hide-gpu-model-interactive' => true,
				'data-hide-gpu-model-other'       => true,
				'data-hide-gpu-model-custom'      => false,
				'data-hide-cuda-version'          => false,
			}]

			{
				'priority' => 61,
				'widget' => 'select',
				'options' => options,
			}
		end

		def stringify_keys(value)
			case value
			when Hash
				value.each_with_object({}) do |(k, v), out|
					out[k.to_s] = stringify_keys(v)
				end
			when Array
				value.map { |item| stringify_keys(item) }
			else
				value
			end
		end

		def deep_merge(left, right)
			left.merge(right) do |_key, old_value, new_value|
				if old_value.is_a?(Hash) && new_value.is_a?(Hash)
					deep_merge(old_value, new_value)
				else
					new_value
				end
			end
		end

		def deep_copy(value)
			Marshal.load(Marshal.dump(value))
		end
	end
end
