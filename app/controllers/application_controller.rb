require 'sinatra'
require 'open-uri'
require 'httparty'
require 'nokogiri'

class ApplicationController < Sinatra::Base
  configure do
  	set :views, "app/views"
  	set :public_dir, "public"
  end

  get "/" do
  	erb :index
  end

  get "/companies" do
    company_name = params["company-name"]
    @@companies = get_companies(company_name)
    @@companies.delete_at(-1)
    @@company_names = generate_company_selection(@@companies)

    if @@companies.empty?
      erb :index
    else
      erb :companies
    end
  end

  get "/reports" do
    selected_company = params["selected-company"]
    index = @@company_names.find_index(selected_company)
    @@reports = get_reports(@@companies[index])
    @@report_dates = generate_report_selection(@@reports)
    erb :reports
  end

  get "/results" do
    selected_report = params["selected-report"]
    index = @@report_dates.find_index(selected_report)
    @@url = extract_report_url(@@reports[index])
    @core_sentences = search_for_core_sentences(paragraphs)
    erb :results
  end

  get "/detailed_results" do
    selected_report = params["selected-report"]
    index = @@report_dates.find_index(selected_report)
    @url = extract_report_url(@@reports[index])
    @paragraphs = analyze_report(@url)
    erb :detailed_results
  end

  get "/about" do
  	erb :about
  end

  private

  def get_companies(query)
    response = post_lookup(query)
    if response.code == 200
      companies = []
      doc = Nokogiri::HTML.parse(response.body)
      raw_companies = doc.search('a')
      raw_companies.each do |company|
        companies.append(company)
      end
      companies
    elsif response.body.nil?
      response.body
    end
  end

  def get_company_name(raw_company)
    return -1 if raw_company.nil?

    cik = raw_company.text.strip
    report_type = '10-K'
    annual_reports = "https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK=#{cik}&type=#{report_type}&dateb=&owner=include&count=40&search_text="
    options = {
      headers: { 'User-Agent': 'Lucas Nseyep lucas.nseyep@gmail.com' }
    }
    response = HTTParty.get(annual_reports, options)
    reports_html = Nokogiri::HTML.parse(response.body)
    name = reports_html.search('.companyName').children[0]
    return '404 - NAME NOT FOUND' if name.nil?

    name.text.strip
  end

  def get_reports(raw_company)
    reports = []

    cik = raw_company.text.strip
    report_type = '10-K'
    annual_reports = "https://www.sec.gov/cgi-bin/browse-edgar?action=getcompany&CIK=#{cik}&type=#{report_type}&dateb=&owner=include&count=40&search_text="
    options = {
      headers: { 'User-Agent': 'Lucas Nseyep lucas.nseyep@gmail.com' }
    }
    response = HTTParty.get(annual_reports, options)

    reports_html = Nokogiri::HTML.parse(response.body)
    reports_html.search('tr').each_with_index do |report, _index|
      reports.append(report) if report.text.strip.include?(report_type)
    end
    reports
  end

  def extract_report_url(raw_report)
    link = raw_report.search('a')[1].attribute('href').value
    pre_href = "https://www.sec.gov#{link}"
    options = {
      headers: { 'User-Agent': 'Lucas Nseyep lucas.nseyep@gmail.com' }
    }
    response = HTTParty.get(pre_href, options)
    report_html = Nokogiri::HTML.parse(response.body)
    path = report_html.search('#menu_cat1').at_css('a')['href']
    "https://www.sec.gov/#{path.match(/Archives.+/)}"
  end

  def analyze_report(url)
    key_words = ["climate change", "net-zero", "net zero", "sustainability"]
    answer_paragraphs = []
    options = {
      headers: { 'User-Agent': 'Lucas Nseyep lucas.nseyep@gmail.com' }
    }
    response = HTTParty.get(url, options)
    report_html = Nokogiri::HTML.parse(response.body)
    report_html.search('span').each do |paragraph|
      key_words.each do |key_word|
        answer_paragraphs.append(paragraph.text.strip) if paragraph.text.include?(key_word)
      end
    end
    answer_paragraphs.uniq
  end

  def post_lookup(query)
    options = {
      body: {
        company: query
      },
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded'
      }
    }
    HTTParty.post('https://www.sec.gov/cgi-bin/cik_lookup', options)
  end

  def generate_company_selection(companies)
    company_names = []
    companies.each do |company|
      company_names.append(get_company_name(company))
    end
    return company_names
  end

  def generate_report_selection(reports)
    report_dates = []
    reports.each do |report|
      report_dates.append(report.search('td')[3].text)
    end
    return report_dates
  end

  def analyze(text)
    important_sentences = []
    important_words = ["is", "are", "climate change", "net-zero", "net zero", "sustainability"]

    average_words = text.scan(/\w+/).count.to_f / text.scan(/(!|\.|\?)/).count
    sentences = text.split(/(!|\.|\?)/)
    sentences.each do |sentence|
      important_words.each do |word|
        if sentence.scan(/\w+/).count.to_f.between?(average_words * 0.7,
                                                    average_words * 1.4) && sentence =~ /\b#{word}\b/
          important_sentences.append(sentence.strip)
        end
      end
    end
    important_sentences.uniq
  end
end
