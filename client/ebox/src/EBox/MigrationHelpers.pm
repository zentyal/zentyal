package EBox::MigrationHelpers;
use strict;
use warnings;

use EBox;

sub renameTable
{
    my ($oldTable, $newTable) = @_;

    my $exists_query = "SELECT COUNT(*) FROM $oldTable";
    my @queries = (
        "ALTER TABLE $newTable RENAME TO $newTable" . "_new",
        "ALTER TABLE $oldTable RENAME TO $newTable",
        "INSERT INTO $newTable SELECT * FROM $newTable" . "_new",
        "DROP TABLE $newTable" . "_new"
    );

    my $cmd = qq{echo "$exists_query" | sudo su postgres -c 'psql eboxlogs' > /dev/null 2>&1};
    system $cmd;
    if ($? == 0) {
        for my $q (@queries) {
            $cmd = qq{echo "$q" | sudo su postgres -c 'psql eboxlogs' > /dev/null 2>&1};
            system $cmd;
        }
    }
}

1;
