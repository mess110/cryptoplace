$(function () {
  var jsonLoaded = false;
  var mapReady = false;
  var imageRefreshInterval = 60 * 10; // seconds
  var lastData = undefined;
  var marker = undefined;
  var minSend = 0.001;
  json = {};

  isInBottomHalf = function (elm) {
    var rect = elm.getBoundingClientRect();
    var viewHeight = Math.max(document.documentElement.clientHeight, window.innerHeight);
    var viewWidth = Math.max(document.documentElement.clientWidth, window.innerWidth);
    var upDown = !(rect.bottom < 0 || rect.top - viewHeight >= 0);
    var leftRight = !(rect.left < 0 || rect.right - viewWidth >= 0);
    var bottomHalf = rect.top > viewHeight / 2
    return upDown && leftRight && bottomHalf;
  }

  adjustBarPos = function (color) {
    var elem = $('#ctrlPanel');
    if (isInBottomHalf($('.leaflet-marker-icon')[0])) {
      elem.css('top', 0);
      elem.css('bottom', '');
      $('#ctrlPanel').css('border-top', '0px solid #' + color)
      $('#ctrlPanel').css('border-bottom', '')
    } else {
      elem.css('top', '');
      elem.css('bottom', 0);
      $('#ctrlPanel').css('border-top', '')
      $('#ctrlPanel').css('border-bottom', '2px solid #' + color)
    }
  }

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

    $("input[type='text']").on("click", function () {
      $(this).select();
    });
  };

  getRequiredAmount = function (dominantAmount, colorAmount) {
    var value = dominantAmount - colorAmount
    if (value < minSend) {
      value = minSend;
    }
    return value;
  };

  changeColor = function (color) {
    var zeAddr = lastData.addresses.find(function (e) { return e.color === color});
    var dominantColor = lastData.addresses[lastData.dominant_index];
    if (dominantColor.amount === 0) {
        $('.helperText').text("Select a color and send " + minSend + " BTC to color it");
    } else {
      if (dominantColor.color === color) {
        $('.helperText').text(zeAddr.amount + ' BTC are protecting this color');
      } else {
        $('.helperText').text('To change the color send ' + getRequiredAmount(dominantColor.amount, zeAddr.amount) + ' BTC to');
      }
    }
    $('#address').val(zeAddr.address);
    $('.qrcode').attr('src', addressToQr(zeAddr.address));
    $('#ctrlPanel').css('background', 'linear-gradient(white, white, white, #' + color + ')');
    adjustBarPos(zeAddr.color);
  };

  addressToQr = function (address) {
    return "https://chart.googleapis.com/chart?chs=150x150&cht=qr&chl=" + address
  };

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
        this.map.on('dragstart', function (e) {
          $('#ctrlPanel').fadeOut();
        });
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

        marker = L.marker(latlon, {
          'icon': L.icon({
            iconUrl: 'coin.png',
            iconSize: [16, 16],
            iconAnchor: [8, 16]
          })
        });

        marker.addTo(this.map);

        var pointInfo = lastData.addresses[lastData.dominant_index];
        changeColor(pointInfo.color);

        var ctrlPanel = $('#ctrlPanel');
        if (ctrlPanel.css('display') === 'none') {
          ctrlPanel.css('display', 'flex').hide().fadeIn();
        }
      }
    });
  }
  load();
});
