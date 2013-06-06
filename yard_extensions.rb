require 'pp'

YARD::Tags::Library.define_tag("module function", :function)

class YARD::Handlers::Ruby::MethodHandler
  def process
    nobj = namespace
    mscope = scope
    if statement.type == :defs
      if statement[0][0].type == :ident
        raise YARD::Parser::UndocumentableError, 'method defined on object instance'
      end
      meth = statement[2][0]
      nobj = P(namespace, statement[0].source) if statement[0][0].type == :const
      args = format_args(statement[3])
      blk = statement[4]
      mscope = :class
    else
      meth = statement[0][0]
      args = format_args(statement[1])
      blk = statement[2]
    end

    nobj = P(namespace, nobj.value) while nobj.type == :constant
    obj = register MethodObject.new(nobj, meth, mscope) do |o|
      o.visibility = visibility
      o.source = statement.source
      o.signature = method_signature(meth)
      o.explicit = true
      o.parameters = args
    end

    # delete any aliases referencing old method
    nobj.aliases.each do |aobj, name|
      next unless name == obj.name
      nobj.aliases.delete(aobj)
    end if nobj.is_a?(NamespaceObject)

    if mscope == :instance && meth == "initialize"
      unless obj.has_tag?(:return)
        obj.docstring.add_tag(YARD::Tags::Tag.new(:return,
          "a new instance of #{namespace.name}", namespace.name.to_s))
      end
    elsif mscope == :class && obj.docstring.blank? && %w(inherited included
        extended method_added method_removed method_undefined).include?(meth)
      obj.docstring.add_tag(YARD::Tags::Tag.new(:private, nil))
    elsif meth.to_s =~ /\?$/
      if obj.tag(:return) && (obj.tag(:return).types || []).empty?
        obj.tag(:return).types = ['Boolean']
      elsif obj.tag(:return).nil?
        unless obj.tags(:overload).any? {|overload| overload.tag(:return) }
          obj.docstring.add_tag(YARD::Tags::Tag.new(:return, "", "Boolean"))
        end
      end
    end

    if obj.has_tag?(:option)
      # create the options parameter if its missing
      obj.tags(:option).each do |option|
        expected_param = option.name
        unless obj.tags(:param).find {|x| x.name == expected_param }
          new_tag = YARD::Tags::Tag.new(:param, "a customizable set of options", "Hash", expected_param)
          obj.docstring.add_tag(new_tag)
        end
      end
    end

    if info = obj.attr_info
      if meth.to_s =~ /=$/ # writer
        info[:write] = obj if info[:read]
      else
        info[:read] = obj if info[:write]
      end
    end

    parse_block(blk, :owner => obj) # mainly for yield/exceptions

    if obj.has_tag?(:function)
      mscope = :class
      obj = register MethodObject.new(nobj, meth, mscope) do |o|
        o.visibility = :public
        o.source = statement.source
        o.signature = method_signature(meth)
        o.explicit = true
        o.parameters = args
      end

      # delete any aliases referencing old method
      nobj.aliases.each do |aobj, name|
        next unless name == obj.name
        nobj.aliases.delete(aobj)
      end if nobj.is_a?(NamespaceObject)

      if mscope == :class && obj.docstring.blank? && %w(inherited included
          extended method_added method_removed method_undefined).include?(meth)
        obj.docstring.add_tag(YARD::Tags::Tag.new(:private, nil))
      elsif meth.to_s =~ /\?$/
        if obj.tag(:return) && (obj.tag(:return).types || []).empty?
          obj.tag(:return).types = ['Boolean']
        elsif obj.tag(:return).nil?
          unless obj.tags(:overload).any? {|overload| overload.tag(:return) }
            obj.docstring.add_tag(YARD::Tags::Tag.new(:return, "", "Boolean"))
          end
        end
      end

      if obj.has_tag?(:option)
        # create the options parameter if its missing
        obj.tags(:option).each do |option|
          expected_param = option.name
          unless obj.tags(:param).find {|x| x.name == expected_param }
            new_tag = YARD::Tags::Tag.new(:param, "a customizable set of options", "Hash", expected_param)
            obj.docstring.add_tag(new_tag)
          end
        end
      end

      if info = obj.attr_info
        if meth.to_s =~ /=$/ # writer
          info[:write] = obj if info[:read]
        else
          info[:read] = obj if info[:write]
        end
      end

      parse_block(blk, :owner => obj) # mainly for yield/exceptions
    end

    # BEGIN (YUO: when the method has a attribute tag)
    if obj.has_tag?(:attribute)
      if meth.to_s =~ /(.+)=$/ # writer
        namespace.attributes[scope][$1] ||= SymbolHash[:read => nil, :write => nil]
        namespace.attributes[scope][$1][:write] = obj
      elsif args.empty?        # reader
        namespace.attributes[scope][meth] ||= SymbolHash[:read => nil, :write => nil]
        namespace.attributes[scope][meth][:read] = obj
      end
    end
    # END
  end
end

class AttrHandler < YARD::Handlers::Ruby::Base
  handles method_call(:opt_accessor)
  handles method_call(:opt_reader)
  handles method_call(:opt_writer)
  handles method_call(:attr_font)
  handles method_call(:attr_painting)
  handles method_call(:attr_length)
  handles method_call(:attr_coordinate)
  namespace_only

  def process
    read, write = true, true
    case statement.method_name(true)
      when :opt_reader then write = false
      when :opt_writer then read = false
    end

    name = statement.parameters.first.jump(:ident).source
    opt_type = 
        case statement.method_name(true)
        when :opt_accessor, :opt_reader, :opt_writer
          val = statement.parameters[1].children.detect do |node|
                  node.type == :assoc && node.jump(:ident).source == "type"
                end
          case val[1].jump(:ident).source
             when 'hash'
               begin
                 i_type = statement.parameters[1].children.detect do |node|
                            node.type == :assoc && node.jump(:ident).source == "item_type"
                          end
                 case i_type[1].jump(:ident).source
                   when 'boolean' then 'Hash{Symbol => Boolean}'
                   when 'string'  then 'Hash{Symbol => String}'
                   when 'symbol'  then 'Hash{Symbol => Symbol}'
                   when 'integer' then 'Hash{Symbol => Integer}'
                   when 'float'   then 'Hash{Symbol => Float}'
                   when 'length'  then 'Hash{Symbol => Length}'
                   when 'point'   then 'Hash{Symbol => Coordinate}'
                   when 'color'   then 'Hash{Symbol => Color}'
                   when 'font'    then 'Hash{Symbol => Font}'
                   else                'Hash'
                 end
               rescue
                 'Hash'
               end
             when 'array'
               begin
                 i_type = statement.parameters[1].children.detect do |node|
                            node.type == :assoc && node.jump(:ident).source == "item_type"
                          end
                 case i_type[1].jump(:ident).source
                   when 'boolean' then 'Array<Boolean>'
                   when 'string'  then 'Array<String>'
                   when 'symbol'  then 'Array<Symbol>'
                   when 'integer' then 'Array<Integer>'
                   when 'float'   then 'Array<Float>'
                   when 'length'  then 'Array<Length>'
                   when 'point'   then 'Array<Coordinate>'
                   when 'color'   then 'Array<Color>'
                   when 'font'    then 'Array<Font>'
                   else                'Array'
                 end
               rescue
                 'Array'
               end
             when 'hash'    then 'Hash'
             when 'boolean' then 'Boolean'
             when 'string'  then 'String'
             when 'symbol'  then 'Symbol'
             when 'integer' then 'Integer'
             when 'float'   then 'Float'
             when 'length'  then 'Length'
             when 'point'   then 'Coordinate'
             when 'color'   then 'Color'
             when 'font'    then 'Font'
             else                'Object'
           end
        when :attr_font
          'Font'
        when :attr_painting
          'Painting'
        when :attr_length
          'Length'
        when :attr_coordinate
          'Coordinate'
        end

    namespace.attributes[scope][name] ||= SymbolHash[:read => nil, :write => nil]
    {:read => opt_type == 'Boolean' ? "#{name}?" : name, :write => "#{name}="}.each do |type, meth|
      if (type == :read ? read : write)
        obj = YARD::CodeObjects::MethodObject.new(namespace, meth) do |o|
          if type == :write
            doc = "Sets the attribute #{name}\n@param [#{opt_type}] value the value to set the attribute #{name} to."
          else
            doc = "Returns the value of attribute #{name}\n@return [#{opt_type}] the value of attribute #{name}"
          end
          o.docstring = statement.comments.to_s.empty? ? doc : statement.comments
          o.visibility = visibility
          o[:chart_option] = [:opt_accessor, :opt_reader, :opt_writer].include?(statement.method_name(true))
        end
        namespace.attributes[scope][name][type] = obj
        register(obj)
        if type == :write
          unless obj.has_tag?(:param)
            obj.docstring.add_tag(YARD::Tags::Tag.new(:param,
              "the value to set the attribute #{name} to.", opt_type, 'value'))
          end
        else
          unless obj.has_tag?(:return)
            obj.docstring.add_tag(YARD::Tags::Tag.new(:return,
              "the value of attribute #{name}", opt_type))
          end
        end
        if obj.tag(:return) && (obj.tag(:return).types || []).empty?
          obj.tag(:return).types = [opt_type]
        end
      end
    end
  end
end

class YARD::Handlers::Ruby::AttributeHandler
  def process
    return if statement.type == :var_ref || statement.type == :vcall
    read, write = true, false
    params = statement.parameters(false).dup

    # Change read/write based on attr_reader/writer/accessor
    case statement.method_name(true)
    when :attr
      # In the case of 'attr', the second parameter (if given) isn't a symbol.
      if params.size == 2
        write = true if params.pop == s(:var_ref, s(:kw, "true"))
      end
    when :attr_accessor
      write = true
    when :attr_reader
      # change nothing
    when :attr_writer
      read, write = false, true
    end

    begin   # ADD (YUO: when the argument are reference of the constant)

    # Add all attributes
    validated_attribute_names(params).each do |name|
      namespace.attributes[scope][name] ||= SymbolHash[:read => nil, :write => nil]

      # Show their methods as well
      {:read => name, :write => "#{name}="}.each do |type, meth|
        if (type == :read ? read : write)
          namespace.attributes[scope][name][type] = MethodObject.new(namespace, meth, scope) do |o|
            if type == :write
              o.parameters = [['value', nil]]
              src = "def #{meth}(value)"
              full_src = "#{src}\n  @#{name} = value\nend"
              doc = "Sets the attribute #{name}\n@param value the value to set the attribute #{name} to."
            else
              src = "def #{meth}"
              full_src = "#{src}\n  @#{name}\nend"
              doc = "Returns the value of attribute #{name}"
            end
            o.source ||= full_src
            o.signature ||= src
            o.docstring = statement.comments.to_s.empty? ? doc : statement.comments
            o.visibility = visibility
          end

          # Register the objects explicitly
          register namespace.attributes[scope][name][type]
        elsif obj = namespace.children.find {|o| o.name == meth.to_sym && o.scope == scope }
          # register an existing method as attribute
          namespace.attributes[scope][name][type] = obj
        end
      end
    end
    
    # BEGIN (YUO: when the argument are reference of the constant)
    rescue YARD::Parser::UndocumentableError => err
      unless statement.comments.to_s.empty?
        statement.comments.to_s.split(/^[\+]{3,}$/).each do |comment|
          next unless comment =~ /^@attribute(?:\s+\[(?:rw|r|w)\])?\s+([A-Za-z_][0-9A-Za-z_]*)\s*$/
          name = $1
          namespace.attributes[scope][name] ||= SymbolHash[:read => nil, :write => nil]

          # Show their methods as well
          {:read => name, :write => "#{name}="}.each do |type, meth|
            if (type == :read ? read : write)
              namespace.attributes[scope][name][type] = MethodObject.new(namespace, meth, scope) do |o|
                if type == :write
                  o.parameters = [['value', nil]]
                  src = "def #{meth}(value)"
                  full_src = "#{src}\n  @#{name} = value\nend"
                  doc = "Sets the attribute #{name}\n@param value the value to set the attribute #{name} to."
                else
                  src = "def #{meth}"
                  full_src = "#{src}\n  @#{name}\nend"
                  doc = "Returns the value of attribute #{name}"
                end
                o.source ||= full_src
                o.signature ||= src
                o.docstring = statement.docstring = comment
                o.visibility = visibility
              end

              # Register the objects explicitly
              register namespace.attributes[scope][name][type] do |obj|

              end
            elsif obj = namespace.children.find {|o| o.name == meth.to_sym && o.scope == scope }
              # register an existing method as attribute
              namespace.attributes[scope][name][type] = obj
            end
          end
        end
      end
    end
    # END
  end
end

class YARD::CodeObjects::MethodObject
  def attr_info
    return nil unless namespace.is_a?(YARD::CodeObjects::NamespaceObject)
    namespace.attributes[scope][name.to_s.gsub(/[=\?]$/, '')]
  end
end

class YARD::Handlers::Ruby::MacroHandler
  def process
    globals.__attached_macros ||= {}
    if !globals.__attached_macros[caller_method]
      return if IGNORE_METHODS[caller_method]
      return if !statement.comments || statement.comments.empty?
    end
    statement.comments.split(/^[\+]{3,}$/).each do |comment|
      @macro, @docstring = nil, YARD::Docstring.new(comment)
      find_or_create_macro(@docstring)
      return if !@macro && !statement.comments_hash_flag && @docstring.tags.size == 0
      @docstring = expanded_macro_or_docstring
      name = method_name
      raise YARD::Handlers::UndocumentableError, "method, missing name" if name.nil? || name.empty?
      tmp_scope = sanitize_scope
      tmp_vis = sanitize_visibility
      object = MethodObject.new(namespace, name, tmp_scope)
      register(object)
      object.visibility = tmp_vis
      object.dynamic = true
      object.signature = method_signature
      create_attribute_data(object)
    end
  end
end

=begin
class YARD::Handlers::Processor
      def process(statements)
        statements.each_with_index do |stmt, index|
          find_handlers(stmt).each do |handler|
            begin
              handler.new(self, stmt).process
            rescue YARD::Parser::LoadOrderError => loaderr
              raise # Pass this up
            rescue YARD::Handlers::NamespaceMissingError => missingerr
              log.warn "The #{missingerr.object.type} #{missingerr.object.path} has not yet been recognized."
              log.warn "If this class/method is part of your source tree, this will affect your documentation results."
              log.warn "You can correct this issue by loading the source file for this object before `#{file}'"
              log.warn
            rescue YARD::Parser::UndocumentableError => undocerr
              log.warn "in #{handler.to_s}: Undocumentable #{undocerr.message}"
              log.warn "\tin file '#{file}':#{stmt.line}:\n\n" + stmt.show + "\n"
            rescue => e
              log.error "Unhandled exception in #{handler.to_s}:"
              log.error "  in `#{file}`:#{stmt.line}:\n\n#{stmt.show}\n"
              log.backtrace(e)
            end
          end
        end
      end
end
=end
