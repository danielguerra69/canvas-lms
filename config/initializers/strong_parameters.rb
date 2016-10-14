class WeakParameters < ActiveSupport::HashWithIndifferentAccess
  # stealin some code from strong params to make WeakParameters from the values

  def each(&block)
    super do |key, value|
      convert_hashes_to_parameters(key, value)
    end

    super
  end

  def [](key)
    convert_hashes_to_parameters(key, super)
  end

  def fetch(key, *args)
    convert_hashes_to_parameters(key, super, false)
  end

  def delete(key, &block)
    convert_hashes_to_parameters(key, super, false)
  end

  def select!(&block)
    convert_value_to_parameters(super)
  end

  private
  def convert_hashes_to_parameters(key, value, assign_if_converted=true)
    converted = convert_value_to_parameters(value)
    self[key] = converted if assign_if_converted && !converted.equal?(value)
    converted
  end

  def convert_value_to_parameters(value)
    if value.is_a?(Array)
      value.map { |_| convert_value_to_parameters(_) }
    elsif value.is_a?(WeakParameters) || !value.is_a?(Hash)
      value
    else
      self.class.new(value)
    end
  end
end

module ArbitraryStrongishParams
  ANYTHING = Object.new.freeze

  # this is mostly copy-pasted
  def hash_filter(params, filter)
    filter = filter.with_indifferent_access

    # Slicing filters out non-declared keys.
    slice(*filter.keys).each do |key, value|
      next unless value

      if filter[key] == ActionController::Parameters::EMPTY_ARRAY
        # Declaration { comment_ids: [] }.
        array_of_permitted_scalars_filter(params, key)
      elsif filter[key] == ANYTHING
        if filtered = recursive_arbitrary_filter(value)
          params[key] = filtered
        end
      else
        # Declaration { user: :name } or { user: [:name, :age, { address: ... }] }.
        params[key] = each_element(value) do |element|
          if element.is_a?(Hash)
            element = self.class.new(element) unless element.respond_to?(:permit)
            element.permit(*Array.wrap(filter[key]))
          end
        end
      end
    end
  end

  def recursive_arbitrary_filter(value)
    if value.is_a?(Hash)
      hash = {}
      value.each do |k, v|
        hash[k] = recursive_arbitrary_filter(v) if permitted_scalar?(k)
      end
      hash
    elsif value.is_a?(Array)
      arr = []
      value.each do |v|
        if permitted_scalar?(v)
          arr << v
        elsif filtered = recursive_arbitrary_filter(v)
          arr << filtered
        end
      end
      arr
    elsif permitted_scalar?(value)
      value
    end
  end
end
ActionController::Parameters.prepend(ArbitraryStrongishParams)

# default to *non* strong parameters
ActionController::Base.class_eval do
  def strong_anything
    ArbitraryStrongishParams::ANYTHING
  end

  def params
    @_params ||= WeakParameters.new(request.parameters)
  end

  def strong_params
    @_strong_params ||= ActionController::Parameters.new(request.parameters)
  end

  def params=(val)
    @_strong_params = val.is_a?(Hash) ? ActionController::Parameters.new(val) : val
    @_params = val.is_a?(Hash) ? WeakParameters.new(val) : val
  end
end

# completely ignore attr_accessible if it's a strong parameters
module ForbiddenAttributesProtectionWithoutAttrAccessible
  module ClassMethods
    def strong_params
      @strong_params = true
    end

    def strong_params?
      !!@strong_params || (self != ActiveRecord::Base && superclass.strong_params?)
    end
  end

  def sanitize_for_mass_assignment(*options)
    new_attributes = options.first
    if new_attributes.respond_to?(:permitted?)
      raise ActiveModel::ForbiddenAttributesError unless new_attributes.permitted?
      new_attributes
    elsif new_attributes.is_a?(WeakParameters) && self.class.strong_params?
      raise ActiveModel::ForbiddenAttributesError
    else
      super
    end
  end
end

ActiveRecord::Base.include(ForbiddenAttributesProtectionWithoutAttrAccessible)
ActiveRecord::Base.singleton_class.include(ForbiddenAttributesProtectionWithoutAttrAccessible::ClassMethods)

ActionController::ParameterMissing.class_eval do
  def skip_error_report?; true; end
end
