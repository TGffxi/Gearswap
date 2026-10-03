-- Logical, pre-slot-translation contracts extracted from Rahvin's builders.lua merge
-- order. Each layer is a Rahvin-selected set; the expected table locks which later layer
-- wins before compat.gearswap translates slots for LuAshitacast.
return {
    {name='idle base',contract='Idle',layers={{body='Idle',feet='IdleFeet'}},expected={body='Idle',feet='IdleFeet'}},
    {name='engaged base',contract='Engaged',layers={{body='Idle'},{body='TP',hands='TP'}},expected={body='TP',hands='TP'}},
    {name='tp mode',contract='TP',layers={{body='Base'},{body='TP'}},expected={body='TP'}},
    {name='accuracy mode',contract='ACC',layers={{body='TP'},{hands='ACC'}},expected={body='TP',hands='ACC'}},
    {name='damage taken mode',contract='DT',layers={{body='TP'},{body='DT'}},expected={body='DT'}},
    {name='pdl mode',contract='PDL',layers={{body='TP'},{legs='PDL'}},expected={body='TP',legs='PDL'}},
    {name='subtle blow mode',contract='SB',layers={{body='TP'},{hands='SB'}},expected={body='TP',hands='SB'}},
    {name='critical mode',contract='CRIT',layers={{body='TP'},{feet='CRIT'}},expected={body='TP',feet='CRIT'}},
    {name='magic evasion mode',contract='MEVA',layers={{body='TP'},{body='MEVA'}},expected={body='MEVA'}},
    {name='named savage blade overlay',contract='Savage Blade',layers={{head='WS',body='WS'},{head='Savage'}},expected={head='Savage',body='WS'}},
    {name='ranged weaponskill overlay',contract='ranged WS',layers={{head='WS'},{body='RA'},{hands='LastStand'}},expected={head='WS',body='RA',hands='LastStand'}},
    {name='aftermath tier overlay',contract='Aftermath',layers={{body='WS'},{head='AM3'}},expected={body='WS',head='AM3'}},
    {name='weapon lock reasserts pair last',contract='Weapon Lock',layers={{main='SetWeapon',sub='SetShield'},{main='Locked',sub='LockedSub'}},expected={main='Locked',sub='LockedSub'}},
    {name='locked plus range reasserts range',contract='Locked+R',layers={{range='SetRange',ammo='Round'},{range='LockedRange'}},expected={range='LockedRange',ammo='Round'}},
    {name='dual wield offhand',contract='Dual Wield',layers={{main='Sword'},{sub='Dagger'}},expected={main='Sword',sub='Dagger'}},
    {name='two hand clears offhand choice',contract='Two-Hand',layers={{main='Great Axe'}},expected={main='Great Axe'}},
    {name='movement wins over idle feet',contract='Movement',layers={{body='Idle',feet='IdleFeet'},{feet='HeraldGaiters'}},expected={body='Idle',feet='HeraldGaiters'}},
    {name='buff child overlay',contract='Buff overlays',layers={{body='TP',hands='TP'},{hands='HasteBuff'}},expected={body='TP',hands='HasteBuff'}},
    {name='day bonus logical ring',contract='Day bonus',layers={{body='Nuke'},{left_ring='Zodiac'}},expected={body='Nuke',left_ring='Zodiac'}},
    {name='weather bonus logical waist',contract='Weather bonus',layers={{body='Nuke'},{waist='Hachirin'}},expected={body='Nuke',waist='Hachirin'}},
    {name='cure light bonus staff',contract='Cure / Light Bonus',layers={{body='Cure'},{main='Chatoyant'}},expected={body='Cure',main='Chatoyant'}},
    {name='bard instrument exception survives ws protection',contract='BRD instrument',layers={{body='Song'},{range='Gjallarhorn'}},expected={body='Song',range='Gjallarhorn'}},
    {name='geomancy handbell exception survives lock',contract='GEO handbell',layers={{main='Locked',range='Weapon'},{range='Dunna',body='Geomancy'}},expected={main='Locked',range='Dunna',body='Geomancy'}},
}
