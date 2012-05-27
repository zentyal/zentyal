CREATE TABLE IF NOT EXISTS backup_slices(
        tablename VARCHAR(40) NOT NULL,
        id BIGINT NOT NULL,
        beginTs TIMESTAMP NOT NULL,
        endTs TIMESTAMP NOT NULL,
        archived BOOLEAN DEFAULT FALSE,
        timeline INT NOT NULL
) ENGINE = MyISAM;

CREATE UNIQUE INDEX backup_slices_i ON backup_slices (id, tablename, timeline);
