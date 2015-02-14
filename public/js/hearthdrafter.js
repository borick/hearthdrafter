var selected = [null, null, null];
var userList = null;
var dat = {};
var img = "http://wow.zamimg.com/images/hearthstone/cards/enus/original/";
var mode = '';
$(document).ready(function() {
    console.log( "document loaded" );
    $('.card1').click(function() {
        showClassCards(0);
    });
    $('.card2').click(function() {
        showClassCards(1);
    });
    $('.card3').click(function() {
        showClassCards(2);
    });
});

function showClassCards(id) {
    console.log("show class cards clicked"+id);
    var options = {
        valueNames: [ 'name' ],
        item: '<li><div class="name"></div></li>'
    };
    if (userList != null) {
        userList.clear();
    }
    userList = new List('cards', options, cards);
    userList.sort('name');
    card_ids = {};
    for (i = 0; i < cards.length; i++) {
        //create a dict to map names to IDs to avoid having to hack this into list.js.
        card_ids[cards[i]['name']] = cards[i]['id'];
    }
    $(".name").click( function( event ) {
        console.log("clicked");
        event.preventDefault();
        var element = $(this);                     
        selected[id] = element;
        var text = element.text();
        var index = id + 1;
        userList.clear();
        var bg_img = img + card_ids[element.text()] + '.png';
        var card_name = ".card"+index;
        console.log(card_name + ":" + bg_img);
        $(card_name).css('background-image', 'url('+bg_img+')' );
        if (selected[0] != null && selected[1] != null && selected[2] != null) {
            $('.confirm').text("Confirm").button().click( function( event ) {
                event.preventDefault();
                $.get("/draft/card_choice", function( data ) {
                        $('.confirm').remove();
                        selected = [];
                        mode = 'confirm_selected';
                });
            });
        }
      } );
    $(".name").css({ width: '210px' });
    $(".card*").css({ position: 'absolute' });
//     $('.confirm').click( function( event ) {
//         event.preventDefault();
//         $.get( "", function( data ) {
//                 console.log(data);
//                 console.log( "Load was performed." );
// });
}

function preload(arrayOfImages) {
    $(arrayOfImages).each(function(){
        $('<img/>')[0].src = this;
    });
}
var images = ['http://wow.zamimg.com/images/hearthstone/cardbacks/original/Card_Back_Default.png'];
for (i = 0; i < cards.length; i++) {
    images.push(img + cards[i]['id']);
}
preload(images);