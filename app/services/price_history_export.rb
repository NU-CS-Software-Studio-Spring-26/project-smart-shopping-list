require "csv"
require "prawn"
require "prawn/table"

class PriceHistoryExport
  HEADERS = [
    "Product",
    "Category",
    "Store",
    "Price",
    "Source",
    "Recorded at",
    "URL",
    "Notes"
  ].freeze

  # Colours kept in sync with the in-app pt-* design tokens so the PDF
  # looks like a printable extension of the product detail page.
  PDF_INK    = "1D1D1F"
  PDF_MUTED  = "6E6E73"
  PDF_LINE   = "D2D2D7"
  PDF_ACCENT = "0058B0"
  PDF_GREEN  = "1D7D3F"
  PDF_RED    = "D70015"

  def self.to_csv(product)
    new(product).to_csv
  end

  def self.to_pdf(product)
    new(product).to_pdf
  end

  def initialize(product)
    @product = product
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << HEADERS

      price_records.each do |record|
        csv << [
          product.name,
          product.category,
          record.store_name,
          format("%.2f", record.price),
          record.source.presence || "manual",
          record.recorded_at.iso8601,
          record.url,
          record.notes
        ]
      end
    end
  end

  # Renders the product's price history as a one-or-two-page PDF with:
  #   * a cover header ("P/T · PriceTracker · Price history report")
  #   * the product name + category + URL
  #   * a summary card (latest / lowest / highest / observations / target)
  #   * a price-trend sparkline plotted from the actual records
  #   * a tabular history of every observation, newest first
  def to_pdf
    Prawn::Document.new(page_size: "LETTER", margin: 48) do |pdf|
      render_header(pdf)
      render_title_block(pdf)
      render_summary_card(pdf)
      render_sparkline(pdf) if price_records.size >= 2
      render_history_table(pdf)
      render_footer(pdf)
    end.render
  end

  private

  attr_reader :product

  def price_records
    @price_records ||= product.price_records.order(recorded_at: :asc, id: :asc).to_a
  end

  def render_header(pdf)
    pdf.fill_color PDF_INK
    pdf.font_size(11) do
      pdf.formatted_text [
        { text: "P/T  ", styles: [ :bold ], color: PDF_INK },
        { text: "PriceTracker  ", styles: [ :bold ] },
        { text: "·  Price history report", color: PDF_MUTED }
      ]
    end
    pdf.move_down 4
    pdf.fill_color PDF_MUTED
    pdf.text "Generated #{Time.current.strftime('%b %-d, %Y at %-I:%M %p')}", size: 9
    pdf.move_down 10
    pdf.stroke_color PDF_LINE
    pdf.stroke_horizontal_rule
    pdf.move_down 18
  end

  def render_title_block(pdf)
    pdf.fill_color PDF_INK
    pdf.text product.name, size: 22, style: :bold, leading: 2
    pdf.move_down 4
    pdf.fill_color PDF_MUTED
    pdf.text product.category.to_s, size: 11
    if product.source_url.present?
      pdf.move_down 2
      pdf.formatted_text [ { text: product.source_url, color: PDF_ACCENT, link: product.source_url, size: 9 } ]
    end
    pdf.move_down 16
  end

  def render_summary_card(pdf)
    prices = price_records.map { |r| r.price.to_f }
    latest = prices.last
    lowest = prices.min
    highest = prices.max
    count  = prices.size
    target = product.target_price&.to_f

    rows = [
      [ "Latest",       latest ? "$#{format('%.2f', latest)}" : "—" ],
      [ "Lowest ever",  lowest ? "$#{format('%.2f', lowest)}" : "—" ],
      [ "Highest ever", highest ? "$#{format('%.2f', highest)}" : "—" ],
      [ "Observations", count.to_s ],
      [ "Target",       target ? "$#{format('%.2f', target)}" : "—" ]
    ]

    pdf.fill_color PDF_INK
    pdf.text "Summary", size: 11, style: :bold
    pdf.move_down 6
    pdf.table(rows, cell_style: { borders: [ :bottom ], border_color: PDF_LINE, padding: [ 6, 8 ], size: 11 }, column_widths: [ 140, 140 ]) do
      column(0).font_style = :normal
      column(0).text_color = PDF_MUTED
      column(1).font_style = :bold
      column(1).text_color = PDF_INK
    end
    pdf.move_down 18
  end

  # A minimalist sparkline rendered with Prawn primitives so we don't need
  # to spin up Chart.js / wkhtmltopdf. Y-axis is the price domain, X-axis
  # is the recorded_at sequence. Y is auto-scaled with a 5% margin.
  def render_sparkline(pdf)
    prices = price_records.map { |r| r.price.to_f }
    return if prices.size < 2

    width  = pdf.bounds.width
    height = 120
    pad_x  = 4
    pad_y  = 4

    y_min = prices.min
    y_max = prices.max
    y_min, y_max = y_min - 1, y_max + 1 if y_min == y_max
    y_range = (y_max - y_min) * 1.05

    points = prices.each_with_index.map do |price, i|
      x = pad_x + (width - 2 * pad_x) * (i.to_f / (prices.size - 1))
      y_norm = (price - y_min) / y_range
      y = pad_y + (height - 2 * pad_y) * (1 - y_norm)
      [ x, height - y ] # bounding_box origin bottom-left
    end

    pdf.fill_color PDF_INK
    pdf.text "Price trend", size: 11, style: :bold
    pdf.move_down 6

    pdf.bounding_box([ 0, pdf.cursor ], width: width, height: height) do
      # Background
      pdf.fill_color "F5F5F7"
      pdf.fill_rectangle [ 0, height ], width, height
      # Polyline
      pdf.stroke_color PDF_ACCENT
      pdf.line_width 1.5
      points.each_cons(2) { |a, b| pdf.stroke_line a, b }
      # Dots
      pdf.fill_color PDF_ACCENT
      points.each { |x, y| pdf.fill_circle [ x, y ], 2 }
      # Endpoints labels
      pdf.fill_color PDF_INK
      pdf.draw_text "$#{format('%.2f', prices.first)}", at: [ points.first[0] + 4, points.first[1] + 4 ], size: 8
      pdf.draw_text "$#{format('%.2f', prices.last)}",  at: [ [ points.last[0] - 40, 0 ].max, points.last[1] + 4 ], size: 8
    end
    pdf.move_down 22
  end

  def render_history_table(pdf)
    pdf.fill_color PDF_INK
    pdf.text "Observations", size: 11, style: :bold
    pdf.move_down 6

    header = [ "Date", "Store", "Price", "Source", "Notes" ]
    body = price_records.reverse.map do |r|
      [
        r.recorded_at.strftime("%b %-d, %Y"),
        r.store_name.to_s,
        "$#{format('%.2f', r.price)}",
        (r.source.presence || "manual").upcase,
        r.notes.to_s
      ]
    end

    pdf.table([ header ] + body,
              header: true,
              column_widths: [ 90, 110, 70, 60, 180 ],
              cell_style: { borders: [ :bottom ], border_color: PDF_LINE, padding: [ 5, 6 ], size: 9 }) do
      row(0).font_style = :bold
      row(0).text_color = PDF_MUTED
      row(0).background_color = "FBFBFD"
      column(2).align = :right
      column(2).font_style = :bold
    end
  end

  def render_footer(pdf)
    pdf.number_pages "<page> / <total>", at: [ pdf.bounds.right - 50, 0 ], align: :right, size: 9, color: PDF_MUTED
  end
end
