CREATE TABLE mailfilter_smtp_report (
        date DATE NOT NULL,        
        
        event VARCHAR(255) NOT NULL,
        action VARCHAR(255) NOT NULL,    

        from_domain VARCHAR(320) NOT NULL,
        to_domain VARCHAR(320) NOT NULL,
        messages BIGINT NOT NULL
);
