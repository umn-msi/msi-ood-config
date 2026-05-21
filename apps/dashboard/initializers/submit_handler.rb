require 'yaml'

class MSI
  class SubmitHandler
    attr_reader :slurm_args, :partitions, :script, :batch_connect

    # Build an MSI::SubmitHandler from an ERB binding.
    #
    # The binding must expose the standard MSI form variables as methods or
    # local variables (OOD exposes them as methods on the context object):
    #   resources, partitions, custom_partitions,
    #   nodes, ntasks, memory, scratch, gpus,
    #   gpu_model_interactive, gpu_model_other,
    #   num_hours, custom_time, account
    #
    # An optional block receives the handler instance before rendering,
    # allowing apps to customise batch_connect and script settings:
    #
    #   MSI::SubmitHandler.from_binding(binding) do |h|
    #     h.batch_connect['template']    = 'basic'
    #     h.batch_connect['conn_params'] = ['jupyter_api']
    #   end
    def self.from_binding(ctx, &block)
      vars = {
        resources:             ctx.eval('resources'),
        partitions:            ctx.eval('partitions'),
        custom_partitions:     ctx.eval('custom_partitions'),
        nodes:                 ctx.eval('nodes'),
        ntasks:                ctx.eval('ntasks'),
        memory:                ctx.eval('memory'),
        scratch:               ctx.eval('scratch'),
        gpus:                  ctx.eval('gpus'),
        gpu_model_interactive: ctx.eval('gpu_model_interactive'),
        gpu_model_other:       ctx.eval('gpu_model_other'),
        gpu_model_custom:      ctx.eval('gpu_model_custom'),
        num_hours:             ctx.eval('num_hours'),
        custom_time:           ctx.eval('custom_time'),
        account:               ctx.eval('account'),
      }
      new(vars, &block)
    end

    def initialize(vars, &block)
      @account     = vars[:account].to_s
      @num_hours   = vars[:num_hours].to_s
      @custom_time = vars[:custom_time].to_s

      @gpu_model_interactive = vars[:gpu_model_interactive].to_s
      @gpu_model_other       = vars[:gpu_model_other].to_s
      @gpu_model_custom      = vars[:gpu_model_custom].to_s

      @partitions  = resolve_partitions(vars)
      @slurm_args  = build_slurm_args(vars)

      @batch_connect = {}
      @script        = {}

      block.call(self) if block
    end

    # Render the final submit YAML string.
    def render
      output = { 'script' => base_script.merge(@script) }

      unless @batch_connect.empty?
        output = { 'batch_connect' => @batch_connect }.merge(output)
      end

      YAML.dump(output)
    end

    private

    def resolve_partitions(vars)
      if vars[:resources] == 'custom'
        vars[:partitions] == 'custom' ? vars[:custom_partitions].to_s : vars[:partitions].to_s
      else
        result = vars[:resources].to_s.match(/([\w\-]+):(\d+):(\d+):(\d+):(\d+):(\d+)/)
        raise "Could not parse resources value: #{vars[:resources].inspect}" if result.nil?

        # Side-load the remaining parsed values so build_slurm_args can reuse them.
        @parsed_resources = {
          nodes:  result[2],
          ntasks: result[3],
          memory: result[4],
          scratch: result[5],
          gpus:   result[6],
        }
        result[1]
      end
    end

    def effective_resources(vars)
      @parsed_resources || {
        nodes:   vars[:nodes].to_s,
        ntasks:  vars[:ntasks].to_s,
        memory:  vars[:memory].to_s,
        scratch: vars[:scratch].to_s,
        gpus:    vars[:gpus].to_s,
      }
    end

    def build_slurm_args(vars)
      res  = effective_resources(vars)
      args = []

      args.concat ['--nodes',          (res[:nodes].empty?  ? '1' : res[:nodes])]
      args.concat ['--ntasks-per-node', (res[:ntasks].empty? ? '1' : res[:ntasks])]
      args.concat ['--mem',            (res[:memory].empty? ? '8192' : res[:memory])]
      args.concat ['--tmp',            res[:scratch]] unless res[:scratch].to_s.empty?

      gres = build_gres(res[:gpus])
      args.concat ['--gres', gres] if gres

      args.concat time_args

      args
    end

    def build_gres(gpus_str)
      count = gpus_str.to_i
      return nil if count <= 0

      model = MSI.resolve_gpu_model(
        @partitions,
        interactive: @gpu_model_interactive,
        other:       @gpu_model_other,
        custom:      @gpu_model_custom
      )

      model ? "gpu:#{model}:#{count}" : "gpu:#{count}"
    end

    def time_args
      if @num_hours == '0'
        ['--time', @custom_time]
      elsif @num_hours == '-1'
        ['--time', (MSI.seconds_to_maintenance / 60).to_i.to_s]
      else
        ['--time', (@num_hours.to_i * 60).to_s]
      end
    end

    def base_script
      {
        'accounting_id' => @account,
        'queue_name'    => @partitions,
        'native'        => @slurm_args,
      }
    end
  end
end
