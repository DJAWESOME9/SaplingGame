-- Apply after quest_gear.sql. Offer standard adventure equipment as quest rewards.
-- Custom workshop pieces stay quest-only; the game drop catalog is unchanged.
insert into public.quest_gear(name,slot,hp,attack,defense)
select seed.name,seed.slot,seed.hp,seed.attack,seed.defense
from (values
  ('Thorn Lance','weapon',0,4,0),
  ('Twig Saber','weapon',2,3,0),
  ('Stinger Pike','weapon',0,5,0),
  ('Pebble Hammer','weapon',4,3,0),
  ('Bramble Bow','weapon',0,4,1),
  ('Amber Fang','weapon',3,4,0),
  ('Bark Plate','armor',8,0,2),
  ('Moss Vest','armor',12,0,1),
  ('Seed Shell','armor',6,0,3),
  ('Acorn Helm','armor',8,1,1),
  ('Resin Mail','armor',10,0,2),
  ('Beetle Carapace','armor',5,0,3),
  ('Dew Pendant','charm',10,1,0),
  ('Pollen Brooch','charm',4,2,1),
  ('Root Charm','charm',6,0,2),
  ('Sunstone','charm',3,3,0),
  ('Moonseed','charm',8,1,1),
  ('Grove Medal','charm',5,2,1)
) as seed(name,slot,hp,attack,defense)
where not exists (
  select 1 from public.quest_gear g where g.name=seed.name and g.slot=seed.slot
);
