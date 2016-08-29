#!/usr/bin/env ruby

require 'nokogiri'

def clean text
  cleaned = text
  cleaned.gsub!(/\u00a0/, ' ')
  cleaned.gsub!(/ {2,}/, ' ')
  cleaned.gsub!(/\u201c/, '``')
  cleaned.gsub!(/\u201d/, "''")
  cleaned.gsub!(/\s*\u2013\s*/, "---")
  cleaned.gsub!(/\u2018/, "`")
  cleaned.gsub!(/\u2019/, "'")
  cleaned.gsub!(/\u00ed/, "\\\\'{i}")
  cleaned.gsub!(/\u00e1/, "\\\\'{a}")
  cleaned.gsub!(/"(\s|,|$)/, "''\\1")
  cleaned.gsub!(/(\s|^)"/, '\1``')
  cleaned.gsub!(/&/, '\\\\&')
  cleaned.gsub!(/_/, '\textunderscore{}')
  cleaned.gsub!(/%/, '\\\\%')
  cleaned.gsub!(/#/, '\\\\#')
  cleaned
end

def has_class node, clazz
  node.has_attribute?('class') && node['class'] =~ /\b#{clazz}\b/
end

def visit node
  if has_class(node, $hideclass)
    return
  end

  if node.name =~ /^h([123])$/
    order = $1.to_i
    header = clean(node.inner_text)
    if !header.empty?
      puts "\\#{'sub' * (order - 1)}section{#{header.gsub(/^(\d|\.)*[[:space:]]*/, '').gsub(/[[:space:]]*$/, '')}}"
    end
  else
    if has_class(node, $emclass)
      print '{\em '
    end

    if has_class(node, $ttclass)
      print '{\tt '
    end

    if has_class(node, $quoteclass)
      print '\begin{quote}'
    end

    if node.name == 'p'
      puts
      puts
    elsif node.name == 'ul' || node.name == 'ol'
      puts "\\begin{#{node.name == 'ul' ? 'itemize' : 'enumerate'}}"
      $listIDs << node['class'].gsub(/.*(lst-\S*).*/, '\1')
      STDERR.puts $listIDs.last
    elsif node.name == 'li'
      print '\item '
    elsif node.name == 'img'
      puts <<EOF
\\begin{figure}
\\centering
\\includegraphics[width=\\linewidth]{#{node['src']}}
\\caption{An image}
\\label{image#{$nimages}}
\\end{figure}
EOF
      $nimages += 1
    elsif node.text?
      print clean(node.text)
    end

    if !node.children.empty?
      child = node.children.first
      while child
        visit child
        child = child.next
      end
    end

    if node.name == 'li'
      puts

      # if last and next ../next is list with same lst_ class but -1
      #   process it
      #   remove it
      nestedID = $listIDs.last.gsub(/(\d+)$/) { $1.to_i + 1 }
      if node == node.parent.last_element_child &&
         (node.parent.next.name == 'ul' || node.parent.next.name == 'ol') &&
         node.parent.next['class'] =~ /\b#{nestedID}\b/
        visit node.parent.next
        node.parent.next.remove
      end
    elsif node.name == 'ul' || node.name == 'ol'
      # if next is list with same lst_ class
      #   process its children
      #   remove it
      while (node.next.name == 'ol' || node.next.name == 'ul') &&
            node.next['class'] =~ /\b#{$listIDs.last}\b/
        node.next.children.each do |child|
          visit child
        end
        node.next.remove
      end
      puts "\\end{#{node.name == 'ul' ? 'itemize' : 'enumerate'}}"
      $listIDs.pop
    end

    if has_class(node, $quoteclass)
      print '\end{quote}'
    end

    if has_class(node, $emclass)
      print '}'
    end

    if has_class(node, $ttclass)
      print '}'
    end
  end
end

doc = File.open(ARGV[0]) { |f| Nokogiri::HTML(f) }

# Remove footnotes/comments.
doc.xpath("//sup[a[starts-with(@id, 'cmnt_')]]").remove
doc.xpath("//div[p/a[starts-with(@id, 'cmnt')]]").remove

# Remove everything after references.
doc.xpath("//p[span[text()='References']]/following-sibling::p").remove
doc.xpath("//p[span[text()='References']]").remove

# Extract abstract.
abstract = doc.xpath("//p[span[text()='Abstract']]/following-sibling::node()[following-sibling::p[span[starts-with(text(),'In some senses')]]]").remove
doc.xpath("//p[span[text()='Abstract']]").remove

# Remove title.
doc.xpath("//p[contains(concat(' ', normalize-space(@class), ' '), ' title ')]").remove

css = doc.xpath('/html/head/style').to_s

if css =~ /\.(c\d+)\{font-family:"Courier New"\}/
  $ttclass = $1
else
  raise 'No code class found!'
end

if css =~ /\.(c\d+)\{font-style:italic\}/
  $emclass = $1
else
  raise 'No code class found!'
end

if css =~ /\.(c\d+)\{margin-left:36pt\}/
  $quoteclass = $1
else
  raise 'No quote class found!'
end

if css =~ /\.(c\d+)\{color:#ff9900\}/
  $hideclass = $1
else
  raise 'No hide class found!'
end

# puts css
# exit 1

$nimages = 0
$listIDs = []

puts IO.read('preamble.tex')
puts '\begin{abstract}'
abstract.each do |node|
  visit node
end
puts '\end{abstract}'
visit(doc)

puts '\bibliographystyle{abbrv}'
puts '\bibliography{references}'
puts '\end{document}'
