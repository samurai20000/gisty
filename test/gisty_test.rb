require File.dirname(__FILE__) + '/test_helper.rb'
require "test/unit"
require 'pp'
require 'rr'

class GistyTest < Test::Unit::TestCase
  include RR::Adapters::TestUnit

  def setup
    @gisty_dir = Pathname.new('tmp').realpath.join('gists')
    @gisty = Gisty.new @gisty_dir, 'foo', 'bar'
    stub_open_uri!
    stub_kernel_system!
  end

  def teardown
    FileUtils.rm_rf @gisty_dir
  end

  def stub_open_uri!
    stub(OpenURI).open_uri do |uri|
      filename = uri.to_s.split('/').last.gsub(/[&?=]/, '_')
      path = File.join File.dirname(__FILE__), 'fixtures', filename
      open path
    end
  end

  def stub_kernel_system!
    stub(Kernel).system do |cmd|
      # puts "* '#{cmd}' *"
      case cmd
      when /^git clone/
        id = cmd.split(/[:.]/)[-2]
        system "mkdir -p #{id}"
        system "touch #{File.join(id, id)}"
      else
      end
    end
  end

  def stub_post_form! dummy = 'http://gist.github.com/111111'
    stub(Net::HTTP).post_form do |uri, opt|
      { 'Location' => dummy }
    end
  end

  def test_extract_ids
    url = 'http://gist.github.com/swdyh?page=4'
    ids = Gisty.extract_ids url
    assert ids.include?("6938")
    assert ids.include?("3668")
  end

  def test_extract
    meta = Gisty.extract 'http://gist.github.com/30119'
    assert_equal 'brianleroux', meta[:author]
    assert_equal 4, meta[:files].size
  end

  def test_new
    assert_instance_of Gisty, @gisty
  end

  def test_page_num
    assert_equal 2, @gisty.page_num
  end

  def test_page_urls
    urls = @gisty.page_urls
    assert_equal 2, urls.size
    assert urls.all? { |u| u.match(/page=\d/) }
  end

  def test_remote_ids
    ids = @gisty.remote_ids
    assert_equal 19, ids.size
    assert ids.include?('7205')
    assert ids.include?('bc82698ab357bd8bb433')
  end

  def test_clone
    id = @gisty.remote_ids.first
    pn = @gisty_dir.join id
    @gisty.clone id
  end

  def test_list
    ids = @gisty.remote_ids
    @gisty.clone ids[0]
    @gisty.clone ids[1]
    list = @gisty.list.map { |i| i.first }
    assert list.include?(ids[0])
    assert list.include?(ids[1])
  end

  def test_delete
    id = '11111'
    pn = @gisty_dir.join id
    FileUtils.mkdir(pn)
    @gisty.delete id
    assert !pn.exist?
  end

  def test_sync
    ids = @gisty.remote_ids
    assert !ids.all? { |i| @gisty_dir.join(i).exist? }
    @gisty.sync
    assert ids.all? { |i| @gisty_dir.join(i).exist? }
  end

#   def test_sync_delete
#     id = '12345'
#     assert !@gisty.remote_ids.include?(id)
#     @gisty.clone id
#     assert @gisty_dir.join(id).exist?
#     @gisty.sync true
#     assert !@gisty_dir.join(id).exist?
#   end

  def test_build_params
    path = File.join('test', 'fixtures', 'foo.user.js')
    params = @gisty.build_params path

    assert_equal '.js', params['file_ext[gistfile1]']
    assert_equal 'foo.user.js', params['file_name[gistfile1]']
    assert_equal "// foo.user.js\n", params['file_contents[gistfile1]']
  end

  def test_build_params_multi
    path1 = File.join('test', 'fixtures', 'foo.user.js')
    path2 = File.join('test', 'fixtures', 'bar.user.js')
    params = @gisty.build_params [path1, path2]

    assert_equal '.js', params['file_ext[gistfile1]']
    assert_equal 'foo.user.js', params['file_name[gistfile1]']
    assert_equal "// foo.user.js\n", params['file_contents[gistfile1]']
    assert_equal '.js', params['file_ext[gistfile2]']
    assert_equal 'bar.user.js', params['file_name[gistfile2]']
    assert_equal "// bar.user.js\n", params['file_contents[gistfile2]']
  end

  def test_create
    stub_post_form!
    path = File.join('test', 'fixtures', 'foo.user.js')
    @gisty.create path
  end

  def test_create_multi
    path1 = File.join('test', 'fixtures', 'foo.user.js')
    path2 = File.join('test', 'fixtures', 'bar.user.js')
    @gisty.create [path1, path2]
  end
end

