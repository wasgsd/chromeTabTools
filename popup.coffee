# Copyright (c) 2012 The Chromium Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
app =
  code: 'tabTools'
  dcTabs: []
  ccTabs: []
  tabs: []
  bkTT: ''
  bkTree: {}
  srx : {}
  dt : {}
  T: {}

Array::toDict = (key) ->
  dict = {}
  dict[obj[key]] = obj for obj in this when obj[key]?
  dict

recr = (n, pn, fc, action) ->
  if n?
    action(n, pn)
    if fc(n)?
      recr(fc(n), n, fc, action)
trav = (nodes, pn, fc, action) ->
  $.each(nodes, (i, n) -> #for n in nodes
    if n?
      action(n, pn)
      if fc(n)?
        trav(fc(n), n, fc, action)
    )
  return

addTab = ->
  if (chrome.tabs? )
    chrome.tabs.getAllInWindow( (tabs) ->
      dcTU = []
      # sc = new showdown.Converter()
      tabText = (tab.title + ' '+tab.url for tab in tabs).join(' ')
      # TfidfValue();
      # termFrequencyCount(tabText.split(/[\s:\.\/]+/, 999).filter( (word) -> word not in
      #   ['the','and','for','How','Your','Blog','Google','https','http','html','www','com']) )
      # directoryFrequencyCount();
      # ans = tfidf();
      # tfs = ({term: term, freq: freq} for term, freq of termFrequencyList[0]).sort( (a, b) ->
      #   return b.freq - a.freq  # desc
      #   )

      crossHTML = '<div class="cross">&#x2716</div>'
      wStarHTML = '<div class="wStar">&#9734</div>'
      app.tabs = tabs
      for tab in tabs.sort( (a, b) -> b.index - a.index)
        dc = if tab.discarded then 'd' else 'c'
        img = '<img src="'+tabImage(tab)+'" width=16 height=16 />'
        if img.match('/clock.png')
          img = ''
        $('#'+dc+'cList').append('<div class="'+(if tab.highlighted then'hlTab 'else'') +
          dc + 'cTab trim-text" id="'+tab.id+'" title="'+tab.title+'&#013('+tab.url+')" > ' +
          wStarHTML.replace('<div','<div id="wS'+tab.id+'" ') +
          img + tab.title + crossHTML +
          # '<span class="trim-text url"'+'> ('+tab.url+')</span>'+
          '</div>')
        if(tab.discarded)
          dcTU.push({'title':tab.title, 'url': tab.url } )
          app.dcTabs.push(tab)
        else
          app.ccTabs.push(tab)

      $('.ccTab').mouseup( tabClick )
      if ($('#dcList').children().length > 0)
        $('.dcTab').mouseup( tabClick )
        $('#dcHead').show()
      else
        $('#dcHead').hide()
      $('.cross').mouseup( (e) ->
        chrome.tabs.get( + e.target.parentNode.getAttribute('id'), (tab) ->
          chrome.tabs.remove(tab.id)
          e.stopPropagation()
          )
        e.target.parentNode.remove()
        )
    )
      # $(".ccTab").wrap( "<a class='ccTab' onclick='tabClick({which:2})'></a>" )

      # for i in [0..7]
      #   if (tfs.length>i+1 )#&& tfs[i].term!='the')
      #     ccHTML = ccHTML.split(tfs[i].term).join("<span class='highlight'>"+ tfs[i].term+"</span>")
      #     dcHTML = dcHTML.split(tfs[i].term).join("<span class='highlight'>"+ tfs[i].term+"</span>")


      # $('#ccList').append('<hr/>')
      # $('#dcList').append( $('<button>Test</button>').click( () ->
      #   chrome.bookmarks.getTree( (ns) ->
      #     console.log(ns.length) )
      #   chrome.bookmarks.create({'title': 'new'}, (newFolder) ->
      #     for dc in dcTU
      #       chrome.bookmarks.create({'parentId':newFolder.id
      #       ,'title':dc.title, 'url':dc.url})
      #     )
      #   ) )

loadData = ->
  chrome.bookmarks.search(app.code, (bks) ->

    if (bks.length >= 1)
      app.bkTT = bks[0].id
    chrome.bookmarks.getTree( (bkAll) ->
      app.bkTree = [bkAll[0]]
      tabBk = {}
      trav(app.bkTree, null, ((bk) -> return bk.children) , (bk, fr) ->
        bk.parentNode = fr
        # if (bk.children?)
          # msg.scrBk[bk.id] = srx.search(bk.title, {bool:"OR"})
        tabs = (tab for tab in app.dcTabs.concat(app.ccTabs) when tab.url == bk.url)
        return if tabs.length == 0
        tab = tabs[0]
        if tabBk[tab]?
          tabBk[tab].push(bk)
        else tabBk[tab] = [bk]
        fStarHTML = '<a class="fStar">&#9733</a>'
        folderPath = ''
        recr(fr.parentNode, fr, ((f) ->return f.parentNode), (f, ff) ->
          if ff
            folderPath = ff.title + '/ ' + folderPath)
        # $('.fStar').click( (e)-> window.open('http://www.google.com/'))#e.target.href))
        $('#wS'+tab.id)[0].outerHTML = fStarHTML.replace('<a',
          '<a id="wS'+tab.id+'" title="' + folderPath +
          '" target="_blank" href="chrome://bookmarks/#'+fr.id+'"')
        return
        )

      if localStorage.recentCards
          app.recentCards = app.dt.recentCards = JSON.parse(localStorage.recentCards) # before each boards' cards arrive
      else app.dt.recentCards = []
      $(window).on('message', (e) ->
        card = e.originalEvent.data
        if (localStorage.recentCards)
          recC = JSON.parse(localStorage.recentCards)
          # TODO validate if card Array
        else
          recC = []
        recC = $.grep(recC, (c) -> c.id !=card.id)
        recC.splice(0, 0, card)
        localStorage.recentCards = JSON.stringify(recC)
        )

      if ! Trello?
        return
      Trello.get 'members/me?fields=fullName' +'&boards=starred&board_fields=name,prefs,dateLastView,starred', (d) ->
        d.boards = d.boards.sort( (a, b) -> new Date(b.dateLastView) - new Date(a.dateLastView))
        d.boards = d.boards.toDict('id')
        app.dt = d
        app.dt.tabs = app.tabs
        app.dt.recentCards = app.recentCards

        app.srx = elasticlunr ->
            this.addField('title', {boost: 10} )
            this.addField('url')
            this.setRef('id')
        for tab in app.tabs
            app.srx.addDoc(tab)
        msg = {rc: [], scr: {}, scrBk:{}}
        msg.rc = app.recentCards
        if msg.rc?
          for card in msg.rc 
            msg.scr[card.name] = app.srx.search(card.name, {bool:"OR"})
          msg.idfcache
        $('#sandbox')[0].contentWindow.postMessage(msg, '*')

        app.dt.cards = []
        $('#fullName').text(d.fullName)
        for key, board of app.dt.boards
          Trello.get 'board/'+board.id+'?fields=name&lists=open&list_fields=name&cards=open&card_fields=name,desc,idList,pos', (board) ->
            board.lists = board.lists.toDict('id')
            for card in board.cards
              card.descHTML = new showdown.Converter().makeHtml(card.desc)
            app.dt.boards[board.id].lists = board.lists
            app.dt.boards[board.id].cards = board.cards
            $('#sandbox')[0].contentWindow.postMessage(app.dt.boards[board.id], '*')
        $('#sandbox')[0].contentWindow.postMessage(app.dt, '*')
        return
        # $('#sandbox')[0].contentWindow.on("DOMContentLoaded", () ->
        #   window.postMessage(app.dt, '*')
        #   )
        # $.post({bkAll: bkAll, dt: d}, (T) ->
        #   app.T=T
        #   )
        # # App.refDate = {name: board.idBoard, value: board.idBoard} for board in d.boards
      )
    )

$(document).ready( () ->
  $(document).click( (e) ->
    if (e.which != 3)
      e.preventDefault()
      return false
    )
  )

tabImage = (tab) ->
  if(tab.audible)
    return "/static/clock.png"
  else if (tab.favIconUrl && (tab.favIconUrl.match( "^data:") || /^https?:\/\/.*/.exec(tab.favIconUrl)))
    # if the favicon is a valid URL or embedded data return that
    return tab.favIconUrl
  else if(/^chrome:\/\/extensions\/.*/.exec(tab.url))
    return "/static/clock.png"
  else
    return "/static/clock.png"

tabClick = (e) ->
  if (e.target!=this)
    return
  if (e.which == 2)
    e.preventDefault()
    e.stopPropagation()
    e.target.remove()
    chrome.tabs.get( + $(this).attr('id'), (tab) ->
      chrome.tabs.remove(tab.id)
      )
  else if (e.which == 1)
    chrome.tabs.get( + $(this).attr('id'), (tab) ->
      chrome.tabs.update(tab.id, {active: true} )
    )

# wrapper window, jQuery,
#   key:'654f1af34d6fd053c6e2cc378993941f'

checkAuth = ->
  if ! Trello?
    loadData()
    return
  Trello.authorize
    type: if chrome.extension? then 'popX' else 'popup'
    name: 'Tab Tool', key: '654f1af34d6fd053c6e2cc378993941f', scope:
      read: 'true', write: 'true', account: 'true'
    token_html: 'token.html', expiration: 'never'
    success: authed

window.onload = ->
  if (window.location.href.indexOf("#token") != - 1)
    parts = window.location.href.split("#token=")
    Trello.setToken(parts[1])
    Trello.writeStorage("token", parts[1]) ;

authed = ->
  $('#checkAuth').hide()
  $('loggedin').show()
  loadData()

test = ->
  $('#testBut').click( () ->
    )

# addSelTab2Card = ->
#   #find card: 1.by url,/recent/lunr
#

SCOPES = [
    'https://www.googleapis.com/auth/drive.file',
    'https://www.googleapis.com/auth/drive.metadata.readonly',
    'email',
    'profile',
    # Add other scopes needed by your application.
  ]
initAuthG = ->
  #chrome.identity.getAuthToken { 'interactive': false },
  #  (token) ->
  gapi.client.setApiKey apiKey
  gapi.auth.authorize {
    client_id: clientId
    client_secret: 'dPgjdzoSb--IhUlYIvI0KBYp'
    scope: SCOPES
    immediate: true } ,
      #if token
      gapi.client.load 'drive', 'v2', ->
        request = gapi.client.drive.files.list()
        request.execute (resp) ->
          if ! resp.error
            appendPre 'Files:'
            files = resp.items
            if files and files.length > 0
              i = 0
              while i < files.length
                file = files[i]
                appendPre file.title + ' (' + file.id + ')'
                i++
            else
              appendPre 'No files found.'

checkAuth()
addTab()
# test()
# addSelTab2Card()
# gapi.load 'client:auth', initAuthG
