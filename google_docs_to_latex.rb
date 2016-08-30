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

def has_class node, *clazzes
  clazzes.any? do |clazz|
    node.has_attribute?('class') && node['class'] =~ /\b#{clazz}\b/
  end
end

def visit node
  if has_class(node, $hideclass)
    return
  end

  if node.name =~ /^h([123])$/
    order = $1.to_i
    header = clean(node.inner_text)
    if !header.empty?
      $out.puts "\\#{'sub' * (order - 1)}section{#{header.gsub(/^(\d|\.)*[[:space:]]*/, '').gsub(/[[:space:]]*$/, '')}}"
    end

  elsif node.name == 'table'
    rows = node.xpath('.//tr') 
    ncolumns = rows[0].children.length

    $out.puts "\\begin{tabularx}{\\linewidth}{|#{'X|' * ncolumns}} \\hline"
    rows.each do |row|
      row.children.each_with_index do |child, index|
        $out.puts '&' if index > 0
        visit child
      end
      $out.puts '\\\\ \hline'
    end
    $out.puts "\\end{tabularx}"

  else
    if has_class(node, $emclass)
      $out.print '{\em '
    end

    if has_class(node, $ttclass)
      $out.print '{\tt '
    end

    if node.name != 'li' && has_class(node, *$quote_classes)
      $out.print '\begin{quote}'
    end

    if node.name == 'p'
      $out.puts
      $out.puts
    elsif node.name == 'ul' || node.name == 'ol'
      $out.puts "\\begin{#{node.name == 'ul' ? 'itemize' : 'enumerate'}}"
      $listIDs << node['class'].gsub(/.*(lst-\S*).*/, '\1')
    elsif node.name == 'li'
      $out.print '\item '
    elsif node.name == 'img'
      $out.puts <<EOF
\\begin{figure}
\\centering
\\includegraphics[width=\\linewidth]{#{node['src']}}
\\caption{An image}
\\label{image#{$nimages}}
\\end{figure}
EOF
      $nimages += 1
    elsif node.text?
      $out.print clean(node.text)
    end

    if !node.children.empty?
      child = node.children.first
      while child
        visit child
        child = child.next
      end
    end

    if node.name == 'li'
      $out.puts

      # if last and next ../next is list with same lst_ class but -1
      #   process it
      #   remove it
      nestedID = $listIDs.last.gsub(/(\d+)$/) { $1.to_i + 1 }
      if node == node.parent.last_element_child &&
         (node.parent.next_element.name == 'ul' || node.parent.next_element.name == 'ol') &&
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
      $out.puts "\\end{#{node.name == 'ul' ? 'itemize' : 'enumerate'}}"
      $listIDs.pop
    end

    if node.name != 'li' && has_class(node, *$quote_classes)
      $out.print '\end{quote}'
    end

    if has_class(node, $emclass)
      $out.print '}'
    end

    if has_class(node, $ttclass)
      $out.print '}'
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

def collect_between(first, last)
  result = []
  until first == last
    result << first
    first = first.next
  end
  result
end

# Extract abstract.
# abstract = doc.xpath("//p[span[text()='Abstract']]/following-sibling::node()[following-sibling::p[span[ends-with(text(),'best computer games of all.')]]]").remove
# doc.xpath("//p[span[text()='Abstract']]").remove

abstract_node = doc.xpath("//p[span[text()='Abstract']]").first
quote_node = doc.xpath("//p[span[starts-with(text(),'In some senses')]]").first
abstract = collect_between(abstract_node, quote_node)

abstract.each { |node| node.remove }
# puts abstract

# exit 1

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

$quote_classes = []
# css.scan(/\.(c\d+)\{[^}]*margin-left:36pt/) do
css.scan(/\.(c\d+)\{margin-left:36pt\}/) do
  $quote_classes << $1
end

if $quote_classes.empty?
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

$out = StringIO.new
$out.puts IO.read('preamble.tex')
$out.puts '\begin{abstract}'
# begin
  abstract.each do |node|
    visit node
  end
  $out.puts '\end{abstract}'

  visit(doc)
# rescue
  # puts $out.string
  # raise
# end

$out.puts '\bibliographystyle{abbrv}'
$out.puts '\bibliography{references}'
$out.puts '\end{document}'

latex = $out.string
latex.gsub!(/\s+(?=\\cite)/, '~')

puts latex
