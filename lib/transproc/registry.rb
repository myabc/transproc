require 'forwardable'

module Transproc
  # Container to define transproc functions in, and access them via `[]` method
  # from the outside of the module
  #
  # @example
  #   module FooMethods
  #     extend Transproc::Registry
  #
  #     def self.foo(name, prefix)
  #       [prefix, '_', name].join
  #     end
  #   end
  #
  #   fn = FooMethods[:foo, 'baz']
  #   fn['qux'] # => 'qux_baz'
  #
  #   module BarMethods
  #     extend FooMethods
  #
  #     def self.bar(*args)
  #       foo(*args).upcase
  #     end
  #   end
  #
  #   fn = BarMethods[:foo, 'baz']
  #   fn['qux'] # => 'qux_baz'
  #
  #   fn = BarMethods[:bar, 'baz']
  #   fn['qux'] # => 'QUX_BAZ'
  #
  # @api public
  module Registry
    # @private
    def self.extended(other)
      other.singleton_class.extend Forwardable
    end

    # Builds the transproc function either from a Proc, or from the module method
    #
    # @param [Proc, Symbol] fn
    #   Either a proc, or a name of the module's function to be wrapped to transproc
    # @param [Object, Array] args
    #   Args to be carried by the transproc
    #
    # @return [Transproc::Function]
    #
    # @alias :t
    #
    def [](fn, *args)
      if fn.is_a?(Proc)
        function = fn
      else
        function = send(:method, fn).to_proc
      end
      Function.new(function, args: args)
    end
    alias_method :t, :[]

    # Forwards the named method (transproc) to another module
    #
    # Allows using transprocs from other modules without including those
    # modules as a whole
    #
    # @example
    #   module Foo
    #     def self.foo(value)
    #       value.upcase
    #     end
    #
    #     def self.bar(value)
    #       value.downcase
    #     end
    #  end
    #
    #  module Qux
    #    def self.qux(value)
    #      value.reverse
    #    end
    #  end
    #
    #  module Bar
    #     extend Transproc::Registry
    #
    #     import :foo, from: Foo, as: :baz
    #     import :bar, from: Foo
    #     import Qux
    #  end
    #
    #  Bar[:baz]['Qux'] # => 'QUX'
    #  Bar[:bar]['Qux'] # => 'qux'
    #  Bar[:qux]['Qux'] # => 'xuQ'
    #
    # @param [Module, String, Symbol] name
    # @option [Class] :from The module to take the method from
    # @option [String, Symbol] :as
    #   The name of imported transproc inside the current module
    #
    # @return [itself] self
    #
    # @alias :import
    #
    def uses(name, options = nil)
      name.instance_of?(Module) ? uses_module(name) : uses_method(name, options)
      self
    end
    alias_method :import, :uses

    private

    def uses_method(name, options)
      source = options.fetch(:from)
      target = options.fetch(:as, name)
      singleton_class.def_delegator source, name, target
    end

    def uses_module(const)
      (const.methods - Registry.methods - Registry.instance_methods)
        .each { |name| uses_method(name, from: const) }
    end
  end
end
