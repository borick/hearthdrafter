package HearthModel::Class;
use Moo;
extends 'HearthModel::DbBase';

sub validate_class {
    my ($self,$class_name) = @_;
    my $classData = $self->classData();
    return exists($classData->{$class_name});
}

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