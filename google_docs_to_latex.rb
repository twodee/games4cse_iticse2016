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
  out = StringIO.new

  if has_class(node, $hideclass)
    # do nothing

  elsif node.name =~ /^h([123])$/
    order = $1.to_i
    header = clean(node.inner_text)
    if !header.empty?
      out.puts "\\#{'sub' * (order - 1)}section{#{header.gsub(/^(\d|\.)*[[:space:]]*/, '').gsub(/[[:space:]]*$/, '')}}"
    end

  elsif node.name == 'table'
    rows = node.xpath('.//tr') 
    ncolumns = rows[0].children.length

    # find table marker
    annotation = node.xpath("./preceding-sibling::p[span[starts-with(text(),'\\TABLE')]][1]").children[0].text
    annotation =~ /\[(.*?),(.*?),(.*)\]/
    label = $1
    columns = $2
    caption = clean($3)

    float = annotation =~ /TABLE\*/ ? 'table*' : 'table'

    columns.gsub!(/(?=)/, '|')

    out.puts "\\begin{#{float}}[tb]"
    out.puts "\\begin{tabularx}{\\linewidth}{#{columns}} \\hline"
    
    rowspans = Hash.new

    rows.each do |row|
      icolumn = 0
      saw_rowspan = false
      row.children.each do |child|

        # Advance past any columns filled from above.
        if rowspans.has_key?(icolumn) && rowspans[icolumn] > 0
          while rowspans.has_key?(icolumn) && rowspans[icolumn] > 0
            out.puts '&'
            rowspans[icolumn] -= 1
            if rowspans[icolumn] == 0
              rowspans.delete(icolumn)
            end
            icolumn += 1
          end
        else
          out.puts '&' if icolumn > 0
        end

        if child.has_attribute?('rowspan') && child['rowspan'].to_i > 1
          saw_rowspan = true
          out.print "\\multirow{#{child['rowspan']}}{*}{"
          out.print visit(child).strip
          out.puts "}"
          rowspans[icolumn] = child['rowspan'].to_i - 1
        else
          out.print visit(child)
        end

        icolumn += 1
      end
      out.print "\\\\ "
      if rowspans.empty?
        out.puts "\\hline"
      else
        out.puts "\\cline{2-3}"
      end
    end
    out.puts "\\end{tabularx}"
    out.puts "\\caption{#{caption}}"
    out.puts "\\label{table:#{label}}"
    out.puts "\\end{#{float}}"

  else
    if has_class(node, $emclass)
      out.print '{\em '
    end

    if has_class(node, $ttclass)
      out.print '{\tt '
    end

    if node.name != 'li' && has_class(node, *$quote_classes)
      out.puts '\begin{quote}'
    end

    if node.name == 'p'
      out.puts
      out.puts
    elsif node.name == 'ul' || node.name == 'ol'
      out.puts "\\begin{#{node.name == 'ul' ? 'itemize' : 'enumerate'}}"
      $listIDs << node['class'].gsub(/.*(lst-\S*).*/, '\1')
    elsif node.name == 'li'
      out.print '\item '
    elsif node.name == 'img'
      annotation = node.xpath("../../preceding-sibling::p[span[starts-with(text(),'\\IMAGE')]][1]").children[0].text
      STDERR.puts annotation
      annotation =~ /\[(.*?),(.*)\]/
      STDERR.puts $1
      STDERR.puts $2
      label = $1
      caption = clean($2)
      out.puts <<EOF
\\begin{figure}[tb]
\\centering
\\includegraphics[width=\\linewidth]{#{node['src']}}
\\caption{#{caption}}
\\label{figure:#{label}}
\\end{figure}
EOF
      $nimages += 1
    elsif node.text?
      out.print clean(node.text)
    end

    if !node.children.empty?
      child = node.children.first
      while child
        out.print visit(child)
        child = child.next
      end
    end

    if node.name == 'li'
      out.puts

      # if last and next ../next is list with same lst_ class but -1
      #   process it
      #   remove it
      nestedID = $listIDs.last.gsub(/(\d+)$/) { $1.to_i + 1 }
      if node == node.parent.last_element_child &&
         (node.parent.next_element.name == 'ul' || node.parent.next_element.name == 'ol') &&
         node.parent.next['class'] =~ /\b#{nestedID}\b/
        out.print visit(node.parent.next)
        node.parent.next.remove
      end
    elsif node.name == 'ul' || node.name == 'ol'
      # if next is list with same lst_ class
      #   process its children
      #   remove it
      while (node.next.name == 'ol' || node.next.name == 'ul') &&
            node.next['class'] =~ /\b#{$listIDs.last}\b/
        node.next.children.each do |child|
          out.print visit(child)
        end
        node.next.remove
      end
      out.puts "\\end{#{node.name == 'ul' ? 'itemize' : 'enumerate'}}"
      $listIDs.pop
    end

    if node.name != 'li' && has_class(node, *$quote_classes)
      out.puts '\end{quote}'
    end

    if has_class(node, $emclass)
      out.print '}'
    end

    if has_class(node, $ttclass)
      out.print '}'
    end
  end

  out.string
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

out = StringIO.new
out.puts IO.read('preamble.tex')
out.puts '\begin{abstract}'
abstract.each do |node|
  out.print visit(node)
end
out.puts '\end{abstract}'

out.print visit(doc)

out.puts '\bibliographystyle{abbrv}'
out.puts '\bibliography{references}'
out.puts '\end{document}'

latex = out.string
latex.gsub!(/\s+(?=\\cite)/, '~')

puts latex
