require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class PageTest < Test::Unit::TestCase
  fixtures :webs, :pages, :revisions, :system
  
  def setup
    @page = pages(:first_page)
  end


  def test_lock
    assert !@page.locked?(Time.local(2004, 4, 4, 16, 50))

    @page.lock(Time.local(2004, 4, 4, 16, 30), "DavidHeinemeierHansson")

    assert @page.locked?(Time.local(2004, 4, 4, 16, 50))
    assert !@page.locked?(Time.local(2004, 4, 4, 17, 1))

    @page.unlock

    assert !@page.locked?(Time.local(2004, 4, 4, 16, 50))
  end
  
  def test_lock_duration
    @page.lock(Time.local(2004, 4, 4, 16, 30), "DavidHeinemeierHansson")

    assert_equal 15, @page.lock_duration(Time.local(2004, 4, 4, 16, 45))
  end
  
  def test_plain_name
    assert_equal "First Page", @page.plain_name
  end

  def test_revise
    @page.revise('HisWay would be MyWay in kinda lame', Time.local(2004, 4, 4, 16, 55), 
        'MarianneSyhler', test_renderer)
    @page.reload

    assert_equal 2, @page.revisions.length, 'Should have two revisions'
    assert_equal 'MarianneSyhler', @page.current_revision.author.to_s, 
        'Mary should be the author now'
    assert_equal 'DavidHeinemeierHansson', @page.revisions.first.author.to_s, 
        'David was the first author'
  end
  
  def test_revise_continous_revision
    @page.revise('HisWay would be MyWay in kinda lame', Time.local(2004, 4, 4, 16, 55), 
        'MarianneSyhler', test_renderer)
    @page.reload
    assert_equal 2, @page.revisions.length
    assert_equal 'HisWay would be MyWay in kinda lame', @page.content

    # consecutive revision by the same author within 30 minutes doesn't create a new revision
    @page.revise('HisWay would be MyWay in kinda update', Time.local(2004, 4, 4, 16, 57), 
        'MarianneSyhler', test_renderer)
    @page.reload
    assert_equal 2, @page.revisions.length
    assert_equal 'HisWay would be MyWay in kinda update', @page.content
    assert_equal Time.local(2004, 4, 4, 16, 57), @page.revised_at

    # but consecutive revision by another author results in a new revision
    @page.revise('HisWay would be MyWay in the house', Time.local(2004, 4, 4, 16, 58), 
        'DavidHeinemeierHansson', test_renderer)
    @page.reload
    assert_equal 3, @page.revisions.length
    assert_equal 'HisWay would be MyWay in the house', @page.content

    # consecutive update after 30 minutes since the last one also creates a new revision, 
    # even when it is by the same author
    @page.revise('HisWay would be MyWay in my way', Time.local(2004, 4, 4, 17, 30), 
        'DavidHeinemeierHansson', test_renderer)
    @page.reload
    assert_equal 4, @page.revisions.length
  end

  def test_revise_content_unchanged
    last_revision_before = @page.current_revision
    revisions_number_before = @page.revisions.size
  
    assert_raises(Instiki::ValidationError) { 
      @page.revise(@page.current_revision.content, Time.now, 'AlexeyVerkhovsky', test_renderer)
    }
    
    assert_equal last_revision_before, @page.current_revision(true)
    assert_equal revisions_number_before, @page.revisions.size
  end

  def test_revise_changes_references_from_wanted_to_linked_for_new_pages
    web = Web.find(1)
    new_page = Page.new(:web => web, :name => 'NewPage')
    new_page.revise('Reference to WantedPage, and to WantedPage2', Time.now, 'AlexeyVerkhovsky', 
        test_renderer)
    
    references = new_page.wiki_references(true)
    assert_equal 2, references.size
    assert_equal 'WantedPage', references[0].referenced_name
    assert_equal WikiReference::WANTED_PAGE, references[0].link_type
    assert_equal 'WantedPage2', references[1].referenced_name
    assert_equal WikiReference::WANTED_PAGE, references[1].link_type

    wanted_page = Page.new(:web => web, :name => 'WantedPage')
    wanted_page.revise('And here it is!', Time.now, 'AlexeyVerkhovsky', test_renderer)

    # link type stored for NewPage -> WantedPage reference should change from WANTED to LINKED
    # reference NewPage -> WantedPage2 should remain the same
    references = new_page.wiki_references(true)
    assert_equal 2, references.size
    assert_equal 'WantedPage', references[0].referenced_name
    assert_equal WikiReference::LINKED_PAGE, references[0].link_type
    assert_equal 'WantedPage2', references[1].referenced_name
    assert_equal WikiReference::WANTED_PAGE, references[1].link_type
  end

  def test_rollback
    @page.revise("spot two", Time.now, "David", test_renderer)
    @page.revise("spot three", Time.now + 2000, "David", test_renderer)
    assert_equal 3, @page.revisions(true).length, "Should have three revisions"
    @page.current_revision(true)
    @page.rollback(0, Time.now, '127.0.0.1', test_renderer)
    assert_equal "HisWay would be MyWay in kinda ThatWay in HisWay though MyWay \\\\OverThere -- see SmartEngine in that SmartEngineGUI", @page.current_revision(true).content
  end
end
