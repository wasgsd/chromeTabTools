var SCOPES, addTab, app, authed, checkAuth, initAuthG, loadData, recr, tabClick, tabImage, test, trav;

app = {
  code: 'tabTools',
  dcTabs: [],
  ccTabs: [],
  tabs: [],
  bkTT: '',
  bkTree: {},
  srx: {},
  dt: {},
  T: {}
};

Array.prototype.toDict = function(key) {
  var dict, j, len, obj;
  dict = {};
  for (j = 0, len = this.length; j < len; j++) {
    obj = this[j];
    if (obj[key] != null) {
      dict[obj[key]] = obj;
    }
  }
  return dict;
};

recr = function(n, pn, fc, action) {
  if (n != null) {
    action(n, pn);
    if (fc(n) != null) {
      return recr(fc(n), n, fc, action);
    }
  }
};

trav = function(nodes, pn, fc, action) {
  $.each(nodes, function(i, n) {
    if (n != null) {
      action(n, pn);
      if (fc(n) != null) {
        return trav(fc(n), n, fc, action);
      }
    }
  });
};

addTab = function() {
  if ((chrome.tabs != null)) {
    return chrome.tabs.getAllInWindow(function(tabs) {
      var crossHTML, dc, dcTU, img, j, len, ref, tab, tabText, wStarHTML;
      dcTU = [];
      tabText = ((function() {
        var j, len, results;
        results = [];
        for (j = 0, len = tabs.length; j < len; j++) {
          tab = tabs[j];
          results.push(tab.title + ' ' + tab.url);
        }
        return results;
      })()).join(' ');
      crossHTML = '<div class="cross">&#x2716</div>';
      wStarHTML = '<div class="wStar">&#9734</div>';
      app.tabs = tabs;
      ref = tabs.sort(function(a, b) {
        return b.index - a.index;
      });
      for (j = 0, len = ref.length; j < len; j++) {
        tab = ref[j];
        dc = tab.discarded ? 'd' : 'c';
        img = '<img src="' + tabImage(tab) + '" width=16 height=16 />';
        if (img.match('/clock.png')) {
          img = '';
        }
        $('#' + dc + 'cList').append('<div class="' + (tab.highlighted ? 'hlTab ' : '') + dc + 'cTab trim-text" id="' + tab.id + '" title="' + tab.title + '&#013(' + tab.url + ')" > ' + wStarHTML.replace('<div', '<div id="wS' + tab.id + '" ') + img + tab.title + crossHTML + '</div>');
        if (tab.discarded) {
          dcTU.push({
            'title': tab.title,
            'url': tab.url
          });
          app.dcTabs.push(tab);
        } else {
          app.ccTabs.push(tab);
        }
      }
      $('.ccTab').mouseup(tabClick);
      if ($('#dcList').children().length > 0) {
        $('.dcTab').mouseup(tabClick);
        $('#dcHead').show();
      } else {
        $('#dcHead').hide();
      }
      return $('.cross').mouseup(function(e) {
        chrome.tabs.get(+e.target.parentNode.getAttribute('id'), function(tab) {
          chrome.tabs.remove(tab.id);
          return e.stopPropagation();
        });
        return e.target.parentNode.remove();
      });
    });
  }
};

loadData = function() {
  return chrome.bookmarks.search(app.code, function(bks) {
    if (bks.length >= 1) {
      app.bkTT = bks[0].id;
    }
    return chrome.bookmarks.getTree(function(bkAll) {
      var tabBk;
      app.bkTree = [bkAll[0]];
      tabBk = {};
      trav(app.bkTree, null, (function(bk) {
        return bk.children;
      }), function(bk, fr) {
        var fStarHTML, folderPath, tab, tabs;
        bk.parentNode = fr;
        tabs = (function() {
          var j, len, ref, results;
          ref = app.dcTabs.concat(app.ccTabs);
          results = [];
          for (j = 0, len = ref.length; j < len; j++) {
            tab = ref[j];
            if (tab.url === bk.url) {
              results.push(tab);
            }
          }
          return results;
        })();
        if (tabs.length === 0) {
          return;
        }
        tab = tabs[0];
        if (tabBk[tab] != null) {
          tabBk[tab].push(bk);
        } else {
          tabBk[tab] = [bk];
        }
        fStarHTML = '<a class="fStar">&#9733</a>';
        folderPath = '';
        recr(fr.parentNode, fr, (function(f) {
          return f.parentNode;
        }), function(f, ff) {
          if (ff) {
            return folderPath = ff.title + '/ ' + folderPath;
          }
        });
        $('#wS' + tab.id)[0].outerHTML = fStarHTML.replace('<a', '<a id="wS' + tab.id + '" title="' + folderPath + '" target="_blank" href="chrome://bookmarks/#' + fr.id + '"');
      });
      if (localStorage.recentCards) {
        app.recentCards = app.dt.recentCards = JSON.parse(localStorage.recentCards);
      } else {
        app.dt.recentCards = [];
      }
      $(window).on('message', function(e) {
        var card, recC;
        card = e.originalEvent.data;
        if (localStorage.recentCards) {
          recC = JSON.parse(localStorage.recentCards);
        } else {
          recC = [];
        }
        recC = $.grep(recC, function(c) {
          return c.id !== card.id;
        });
        recC.splice(0, 0, card);
        return localStorage.recentCards = JSON.stringify(recC);
      });
      if (typeof Trello === "undefined" || Trello === null) {
        return;
      }
      return Trello.get('members/me?fields=fullName' + '&boards=starred&board_fields=name,prefs,dateLastView,starred', function(d) {
        var board, card, j, k, key, len, len1, msg, ref, ref1, ref2, tab;
        d.boards = d.boards.sort(function(a, b) {
          return new Date(b.dateLastView) - new Date(a.dateLastView);
        });
        d.boards = d.boards.toDict('id');
        app.dt = d;
        app.dt.tabs = app.tabs;
        app.dt.recentCards = app.recentCards;
        app.srx = elasticlunr(function() {
          this.addField('title', {
            boost: 10
          });
          this.addField('url');
          return this.setRef('id');
        });
        ref = app.tabs;
        for (j = 0, len = ref.length; j < len; j++) {
          tab = ref[j];
          app.srx.addDoc(tab);
        }
        msg = {
          rc: [],
          scr: {},
          scrBk: {}
        };
        msg.rc = app.recentCards;
        if (msg.rc != null) {
          ref1 = msg.rc;
          for (k = 0, len1 = ref1.length; k < len1; k++) {
            card = ref1[k];
            msg.scr[card.name] = app.srx.search(card.name, {
              bool: "OR"
            });
          }
          msg.idfcache;
        }
        $('#sandbox')[0].contentWindow.postMessage(msg, '*');
        app.dt.cards = [];
        $('#fullName').text(d.fullName);
        ref2 = app.dt.boards;
        for (key in ref2) {
          board = ref2[key];
          Trello.get('board/' + board.id + '?fields=name&lists=open&list_fields=name&cards=open&card_fields=name,desc,idList,pos', function(board) {
            var l, len2, ref3;
            board.lists = board.lists.toDict('id');
            ref3 = board.cards;
            for (l = 0, len2 = ref3.length; l < len2; l++) {
              card = ref3[l];
              card.descHTML = new showdown.Converter().makeHtml(card.desc);
            }
            app.dt.boards[board.id].lists = board.lists;
            app.dt.boards[board.id].cards = board.cards;
            return $('#sandbox')[0].contentWindow.postMessage(app.dt.boards[board.id], '*');
          });
        }
        $('#sandbox')[0].contentWindow.postMessage(app.dt, '*');
      });
    });
  });
};

$(document).ready(function() {
  return $(document).click(function(e) {
    if (e.which !== 3) {
      e.preventDefault();
      return false;
    }
  });
});

tabImage = function(tab) {
  if (tab.audible) {
    return "/static/clock.png";
  } else if (tab.favIconUrl && (tab.favIconUrl.match("^data:") || /^https?:\/\/.*/.exec(tab.favIconUrl))) {
    return tab.favIconUrl;
  } else if (/^chrome:\/\/extensions\/.*/.exec(tab.url)) {
    return "/static/clock.png";
  } else {
    return "/static/clock.png";
  }
};

tabClick = function(e) {
  if (e.target !== this) {
    return;
  }
  if (e.which === 2) {
    e.preventDefault();
    e.stopPropagation();
    e.target.remove();
    return chrome.tabs.get(+$(this).attr('id'), function(tab) {
      return chrome.tabs.remove(tab.id);
    });
  } else if (e.which === 1) {
    return chrome.tabs.get(+$(this).attr('id'), function(tab) {
      return chrome.tabs.update(tab.id, {
        active: true
      });
    });
  }
};

checkAuth = function() {
  if (typeof Trello === "undefined" || Trello === null) {
    loadData();
    return;
  }
  return Trello.authorize({
    type: chrome.extension != null ? 'popX' : 'popup',
    name: 'Tab Tool',
    key: '654f1af34d6fd053c6e2cc378993941f',
    scope: {
      read: 'true',
      write: 'true',
      account: 'true'
    },
    token_html: 'token.html',
    expiration: 'never',
    success: authed
  });
};

window.onload = function() {
  var parts;
  if (window.location.href.indexOf("#token") !== -1) {
    parts = window.location.href.split("#token=");
    Trello.setToken(parts[1]);
    return Trello.writeStorage("token", parts[1]);
  }
};

authed = function() {
  $('#checkAuth').hide();
  $('loggedin').show();
  return loadData();
};

test = function() {
  return $('#testBut').click(function() {});
};

SCOPES = ['https://www.googleapis.com/auth/drive.file', 'https://www.googleapis.com/auth/drive.metadata.readonly', 'email', 'profile'];

initAuthG = function() {
  gapi.client.setApiKey(apiKey);
  return gapi.auth.authorize({
    client_id: clientId,
    client_secret: 'dPgjdzoSb--IhUlYIvI0KBYp',
    scope: SCOPES,
    immediate: true
  }, gapi.client.load('drive', 'v2', function() {
    var request;
    request = gapi.client.drive.files.list();
    return request.execute(function(resp) {
      var file, files, i, results;
      if (!resp.error) {
        appendPre('Files:');
        files = resp.items;
        if (files && files.length > 0) {
          i = 0;
          results = [];
          while (i < files.length) {
            file = files[i];
            appendPre(file.title + ' (' + file.id + ')');
            results.push(i++);
          }
          return results;
        } else {
          return appendPre('No files found.');
        }
      }
    });
  }));
};

checkAuth();

addTab();
