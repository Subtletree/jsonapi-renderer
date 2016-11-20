require 'set'

module JSONAPI
  module Renderer
    class ResourcesProcessor
      def initialize(resources, include, fields)
        @resources = resources
        @include   = include
        @fields    = fields
      end

      def process
        traverse_resources
        process_resources

        [@primary, @included]
      end

      private

      def traverse_resources
        @traversed    = Set.new # [type, id, prefix]
        @include_rels = {} # [type, id => Set]
        @queue        = []
        @primary      = []
        @included     = []

        initialize_queue
        traverse_queue
      end

      def initialize_queue
        @resources.each do |res|
          @traversed.add([res.jsonapi_type, res.jsonapi_id, ''])
          traverse_resource(res, @include.keys, true)
          enqueue_related_resources(res, '', @include)
        end
      end

      def traverse_queue
        until @queue.empty?
          res, prefix, include_dir = @queue.pop
          traverse_resource(res, include_dir.keys, false)
          enqueue_related_resources(res, prefix, include_dir)
        end
      end

      def traverse_resource(res, include_keys, primary)
        ri = [res.jsonapi_type, res.jsonapi_id]
        if @include_rels.include?(ri)
          @include_rels[ri].merge!(include_keys)
        else
          @include_rels[ri] = Set.new(include_keys)
          (primary ? @primary : @included) << res
        end
      end

      def enqueue_related_resources(res, prefix, include_dir)
        res.jsonapi_related(include_dir.keys).each do |key, data|
          data.each do |child_res|
            next if child_res.nil?
            child_prefix = "#{prefix}.#{key}"
            enqueue_resource(child_res, child_prefix, include_dir[key])
          end
        end
      end

      def enqueue_resource(res, prefix, include_dir)
        return unless @traversed.add?([res.jsonapi_type,
                                       res.jsonapi_id,
                                       prefix])
        @queue << [res, prefix, include_dir]
      end

      def process_resources
        [@primary, @included].each do |resources|
          resources.map! do |res|
            ri = [res.jsonapi_type, res.jsonapi_id]
            include_dir = @include_rels[ri]
            fields = @fields[res.jsonapi_type.to_sym]
            res.as_jsonapi(include: include_dir, fields: fields)
          end
        end
      end
    end
  end
end
