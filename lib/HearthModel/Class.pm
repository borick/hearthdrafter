package HearthModel::Class;
use Moo;
extends 'HearthModel::DbBase';

has classData => (
    is => 'ro',
    default => sub {
        return { 'druid'    => 1,
                 'hunter'   => 2,
                 'mage'     => 3,
                 'paladin'  => 4,
                 'priest'   => 5,
                 'rogue'    => 6,
                 'shaman'   => 7,
                 'warlock'  => 8,
                 'warrior'  => 9,
               };
        }
);
1;