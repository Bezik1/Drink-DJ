INSERT INTO Ingredient (name, category, alcohol_percentage) VALUES
    ('T Vodka',        'alcohol',  40),
    ('T Gin',          'alcohol',  40),
    ('T Lime Juice',   'addition', 0),
    ('T Simple Syrup', 'addition', 0),
    ('T Soda Water',   'addition', 0),
    ('T Mint',         'addition', 0);

DO $$
BEGIN
    PERFORM register_user('t_alice', 't_alice@example.com', 'Alice-Test-1');
    PERFORM register_user('t_bob',   't_bob@example.com',   'Bob-Test-1');

    PERFORM set_acting_user(NULL);
    PERFORM create_drink('T Gin Sour', 'Gin, lime and sugar.', NULL, 'gin',
        '[{"name": "T Gin", "amount": 50}, {"name": "T Lime Juice", "amount": 25},
          {"name": "T Simple Syrup", "amount": 25}]');

    SET CONSTRAINTS ALL IMMEDIATE;
    SET CONSTRAINTS ALL DEFERRED;
    PERFORM new_transaction();
END
$$;
