var selected = [null, null, null];
var userList = null;
var dat = {};

$(document).ready(function() {
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
    var options = {
        valueNames: [ 'name' ],
        item: '<li><h3 class="name"></h3></li>'
    };
    if (userList != null) {
        userList.clear();
    }
    userList = new List('cards', options, cards);
    userList.sort('name');
    
    $(".name").button().click( function( event ) {
        event.preventDefault();  
        var element = $(this);                     
        selected[id] = element;
        var text = element.text();
        var index = id + 1;
        var remove_card = $('<div class="remove_card">'+text+'</div>')
        $('.card'+index).append(remove_card);
        $(".remove_card").button().click ( function( event ) {
            event.preventDefault();  
            selected[id] = null;
            $(this).remove();
        });
        console.dirxml(selected);
        userList.clear();
      } );
    $(".name").css({ width: '210px' });
    $(".card*").css({ position: 'absolute' });
}

function preload(arrayOfImages) {
    $(arrayOfImages).each(function(){
        $('<img/>')[0].src = this;
    });
}
var images = ['http://wow.zamimg.com/images/hearthstone/cardbacks/original/Card_Back_Default.png'];
preload(images);