
require 'tilt'
require 'tilt/template'

module Tilt
  # Raw Htm (no template functionality). May eventually add syntax validation warnings
  class PlainHtmlTemplate < Template
    self.default_mime_type = 'text/html'

    def self.engine_initialized?
      true
    end

    def prepare
      @rawhtml = data
    end

    def evaluate(scope, locals, &block)
      @output ||= @rawhtml
    end
  end
  
  class RubyPoweredMarkdown < ErubisTemplate
    def evaluate(scope, locals, &block)
       temp = super
       (Tilt["markdown"].new { temp }).render
    end
  end
  

  class MarkdownVars < StringTemplate
    def evaluate(scope, locals, &block)
      temp = super
      (Tilt["markdown"].new { temp }).render
    end
  end 
  register PlainHtmlTemplate, 'htmf'
  register RubyPoweredMarkdown, 'rmd'
  register MarkdownVars, 'mdv'

  def self.alternate_engine_names(engine)
    Enumerator.new  do |y| 
      default = Tilt[engine]
      Tilt.mappings.each do |k,v| 
        y << k if v.include?(default) 
      end
    end
  end
end



module Hardwired


  #Content file support
  module ContentFormats
    @template_mappings = Hash.new { |h, k| h[k] = [] }

    # The set of extensions (without the leading dot) as symbols
    def self.extensions
      @template_mappings.keys
    end

    # Normalizes string extensions to symbols, stripping the leading dot. If passed a symbol, assumes it has already been trimmed.
    def self.normalize(ext)
      (ext.is_a? Symbol) ? ext : ext.to_s.downcase.sub(/^\./, '').to_sym
    end

    # Register a template implementation by file extension.
    def self.register(template_class, *extensions)
      extensions.each do |ext|
        ext = normalize(ext)
        @template_mappings[ext].unshift(template_class).uniq!
      end
    end

    #Removes all implementations registered for the given extensions
    def self.clear(*extensions)
      extensions.each do |ext|
        @template_mappings.delete(normalize(ext))
      end
    end

    # Returns true when a template exists on an exact match of the provided file extension
    def self.registered?(ext)
      ext = normalize(ext)
      @template_mappings.key?(ext) && !@template_mappings[ext].empty?
    end

    # Lookup a class for the given extension
    # Return nil when no implementation is found.
    def self.[](ext)

       #first non-null
       fmt = @template_mappings[normalize(ext)].detect do |klass|
         not klass.nil?
       end
       
       # We don't provide a method for engine initialization like Tilt does - it doubles code complexity and we don't have a use-case yet.
       # Using static methods may be the wrong approach, but since Tilt is handling all the heavy lifting, I don't see one on the horizon.
       return fmt if fmt
    end
   

     
   class Markdown
     def self.heading (markup) markup =~ /\A#\s*(.*?)(\s*#+|$)/ ? $1 : nil
     end
     
     def self.body (markup) markup.sub(/\A#[^#].*$\r?\n(\r?\n)?/, '')  end
   end
   
   class Haml
       def self.heading (markup) markup =~  /\A\s*%h1\s+(.*)/ ? $1 : nil
       end
       def self.body (markup) markup.sub(/\A\s*%h1\s+.*$\r?\n(\r?\n)?/, '') end
   end
   
   class Textile
       def self.heading (markup) 
         markup =~  /^\s*h1\.\s+(.*)/ ? $1 : nil
      end

       def self.body (markup) markup.sub(/\A\s*h1\.\s+.*$\r?\n(\r?\n)?/, '') end
  end
   
   class Html
       def self.heading (markup) markup =~ /\A\s*<h1[^><]*>(.*?)<\/h1>/ ? $1 : nil
       end

       def self.body (markup) markup.sub(/\A\s*<h1[^><]*>.*?<\/h1>\s*/, '') end
    end

   class Slim
       def self.heading (markup) markup =~  /\A\s*h1\s+(.*)/ ? $1 : nil
       end
       def self.body (markup) markup.sub(/\A\s*h1\s+.*$\r?\n(\r?\n)?/, '') end
   end
   
  end

  module MetadataParsing

    def self.separate(text)
        #Support --- (jeykll style) and regular
        return $1, $', true if text =~ /\A(---\s*\n.*?\n?)^(---\s*$\n?)/m or text =~ /\A([A-z ]+:.*?)\r?\n\r?\n/m 
        return "", text, false
    end


    def self.extract(text)
      a,b,found = separate(text)
      m = parse(a)
      b = a + b if m.nil? #Restore non-metadata text
      return (m || {}), b, found && !m.nil?
    end


    def self.parse(metadata_text)
      yaml = YAML.load(metadata_text)
      yaml.is_a?(Hash) ? yaml : nil
    end 


  end 

end
