module RubyLLM
  module Providers
    class Gemini
      module Media
        # Store original method (module method)
        class << self
          alias_method :original_format_content, :format_content
        end
        
        # Override the module method directly
        def self.format_content(content)
          # Convert Hash/Array back to JSON string for API
          return [format_text(content.to_json)] if content.is_a?(Hash) || content.is_a?(Array)
          return [format_text(content)] unless content.is_a?(Content)
          
          if content.class.method_defined?(:format_content)
            return [content.format_content]
          end
          
          # Delegate to original method for base Content class
          original_format_content(content)
        end
      end
    end
  end
end
