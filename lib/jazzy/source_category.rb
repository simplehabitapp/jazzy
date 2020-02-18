require 'jazzy/source_declaration'
require 'jazzy/config'
require 'jazzy/source_mark'
require 'jazzy/jazzy_markdown'

module Jazzy
  # Category (group, contents) pages generated by jazzy
  class SourceCategory < SourceDeclaration
    extend Config::Mixin

    def initialize(group, name, abstract, url_name)
      super()
      self.type     = SourceDeclaration::Type.overview
      self.name     = name
      self.url_name = url_name
      self.abstract = Markdown.render(abstract)
      self.children = group
      self.parameters = []
      self.mark       = SourceMark.new
    end

    def omit_content_from_parent?
      true
    end

    def show_in_sidebar?
      true
    end

    # Group root-level docs into custom categories or by type
    def self.group_docs(docs)
      custom_categories, docs =
        group_custom_categories(docs, config.custom_categories)
      type_categories, uncategorized = group_type_categories(
        docs, custom_categories.any? ? 'Other ' : ''
      )
      custom_categories + merge_categories(type_categories) + uncategorized
    end

    def self.group_custom_categories(docs, categories)
      group = categories.map do |category|
        children = category['children'].flat_map do |child|
          puts child
          puts "child is #{child.class}"
          if child.is_a?(Hash)
            # Nested category, recurse
            docs_with_name, docs = group_custom_categories(docs, [child])
#          elsif child.is_a?(String) && JSON.parse(child).is_a?(Hash)
#            puts "found hash is #{JSON.parse(child)}"
#            docs_with_name, docs = group_custom_categories(docs, [JSON.parse(child)])
          else
            # Doc name, find it
            docs_with_name, docs = docs.partition do |doc|
              if child.is_a?(Regexp)
                doc.name.match(child)
              elsif child.is_a?(String) && child.include?("/")
                regexp = Regexp.new child.tr('/', '')
                doc.name.match(regexp)                  
              else
                doc.name == child
              end
            end

            if docs_with_name.empty?
              STDERR.puts(
                'WARNING: No documented top-level declarations match ' \
                "name \"#{child}\" specified in categories file",
              )
            end
          end
          docs_with_name
        end
        # Category config overrides alphabetization
        children.each.with_index { |child, i| child.nav_order = i }
        make_group(children, category['name'], '')
      end
      [group.compact, docs]
    end

    def self.group_type_categories(docs, type_category_prefix)
      group = SourceDeclaration::Type.all.map do |type|
        children, docs = docs.partition { |doc| doc.type == type }
        make_group(
          children,
          type_category_prefix + type.plural_name,
          "The following #{type.plural_name.downcase} are available globally.",
          type_category_prefix + type.plural_url_name,
        )
      end
      [group.compact, docs]
    end

    # Join categories with the same name (eg. ObjC and Swift classes)
    def self.merge_categories(categories)
      merged = []
      categories.each do |new_category|
        if existing = merged.find { |c| c.name == new_category.name }
          existing.children += new_category.children
        else
          merged.append(new_category)
        end
      end
      merged
    end

    def self.make_group(group, name, abstract, url_name = nil)
      group.reject! { |doc| doc.name.empty? }
      unless group.empty?
        SourceCategory.new(group, name, abstract, url_name)
      end
    end
  end
end
