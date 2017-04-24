$(function () {
  var jsonLoaded = false;
  var mapReady = false;
  var imageRefreshInterval = 60 * 10; // seconds
  var defaultAnchorY = -34;
  var lastData = undefined;
  var marker = undefined;
  json = {};

  setLoading = function (tJsonLoaded, tMapReady) {
    var loadingText = $('#loadingText');

    if (tJsonLoaded !== undefined) {
      jsonLoaded = tJsonLoaded;
      loadingText.text('addresses loaded');
    }

    if (tMapReady !== undefined) {
      mapReady = tMapReady;
      loadingText.text('map ready');
    }

    if (jsonLoaded && mapReady) {
      start();
    }
  }

  start = function () {
    // ta-daaa
    $('.curtain').fadeOut();

    // load first image
    $('.leaflet-image-layer').attr('src', 'api/place.png?timestamp=' + new Date().getTime());

    // refresh image
    setInterval(function () {
      $('.leaflet-image-layer').attr('src', 'api/place.png?timestamp=' + new Date().getTime());
    }, imageRefreshInterval * 1000);

    // init clipboard
    var clipboard = new Clipboard('.btn');
    clipboard.on('success', function(e) {
      var trigger = $(e.trigger);
      if (trigger.text() == 'copied') {
        trigger.text(trigger.data('clipboard-text'));
      } else {
        trigger.text('copied');
      }
      e.clearSelection();
    });
  };

  changeColor = function (color) {
    var zeAddr = lastData.addresses.find(function (e) { return e.color === color});
    $('.address').text(zeAddr.address);
    $('.cube').css('background-color', "#" + color);
    $('.qrcode').attr('src', addressToQr(zeAddr.address));
  };

  addressToQr = function (address) {
    return "https://chart.googleapis.com/chart?chs=150x150&cht=qr&chl=" + address
  };

  popupHtml = function () {
    var data = lastData;
    var zeAddr = data.addresses.find(function (e) { return e.color === data.color });
    var result =  "<div style='line-height: 0.7'>";
    result += "  <span class='cube' style='background-color: #" + data.color + "'></span>";
    result += "  <img class='qrcode' src='" + addressToQr(zeAddr.address) + "' />";
    result += "  <br />";
    result += "  <br />";
    result += "  <br />";
    result += " <button class='btn address' data-clipboard-text='" + zeAddr.address + "'>" + zeAddr.address + "</button>";

    result += "  <br />";
    result += "  <br />";
    result += "  <br />";
    for (var i = 0, l = json.colors.length; i < l; i++) {
      var color = json.colors[i];
      result += "<span class='small-cube', style='background-color: #" + color + "' onclick=\"changeColor('" + color + "')\"></span>";
    }
    result += "</div>";
    return result;
  }

  load = function () {
    // Load addresses so we can display them in the UI
    $.getJSON( "api/place.json", function( data ) {
      json = data;
      setLoading(true, undefined);
    });

    // Init the map
    $("#image1").imgViewer2({
      zoomMax: 30,
      // zoomStep: 0.5,
      onReady: function() {
        $('.leaflet-grab').css('cursor','default');
        this.setZoom(6);
        setLoading(undefined, true);
        this.map.doubleClickZoom.disable();
      },
      onClick: function( e, pos ) {
        if (pos === null) {
          return;
        }
        var pixelPos = {
          x: Math.floor(pos.x * this.img.naturalWidth),
          y: Math.floor(pos.y * this.img.naturalHeight)
        };

        lastData = json.map[pixelPos.x + "," + pixelPos.y];

        var latlon = {
          lat: this.img.naturalHeight - pixelPos.y - 0.75,
          lon: pixelPos.x + 0.5
        };

        if (marker !== undefined) {
          marker.remove();
        }

        var anchorY = defaultAnchorY;
        if (pixelPos.y < 23) {
          anchorY += 377;
        }
        marker = L.marker(latlon, {
          'icon': L.icon({
            iconUrl: 'coin.png',
            iconSize:     [32, 32],
            iconAnchor:   [16, 32],
            popupAnchor:  [0, anchorY]
          })
        });

        marker.addTo(this.map).bindPopup(popupHtml());
        marker.openPopup();

        if (anchorY == defaultAnchorY) {
          $('.leaflet-popup-tip-container').css('bottom', '');
          $('.leaflet-popup-tip-container').css('transform', '');
        } else {
          $('.leaflet-popup-tip-container').css('bottom', 311);
          $('.leaflet-popup-tip-container').css('transform', 'rotate(180deg)');
        }
      }
    });
  }
  load();
});
