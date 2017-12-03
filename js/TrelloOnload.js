  window.onload = function() {
    var parts;
    if (window.location.href.indexOf("#token") !== -1) {
      parts = window.location.href.split("#token=");
      Trello.setToken(parts[1]);
      Trello.writeStorage("token", parts[1]);
      // Trello.persistToken();
    }
  };
