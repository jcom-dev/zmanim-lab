-- Story 4.5: Halachic Documentation
-- Add halachic_notes field to zman_definitions table

-- Add halachic_notes column
ALTER TABLE zman_definitions
ADD COLUMN IF NOT EXISTS halachic_notes TEXT;

-- Add halachic_source column for structured citation reference
ALTER TABLE zman_definitions
ADD COLUMN IF NOT EXISTS halachic_source VARCHAR(500);

-- Comment on columns
COMMENT ON COLUMN zman_definitions.halachic_notes IS 'Markdown-formatted halachic documentation and sources';
COMMENT ON COLUMN zman_definitions.halachic_source IS 'Primary halachic source reference';

-- Add default halachic notes for some standard zmanim
UPDATE zman_definitions
SET halachic_notes = '## Source

This calculation follows the opinion of the **Vilna Gaon** (GRA) who rules that the day begins at sunrise (נץ החמה).

### References
- [Shulchan Aruch OC 233:1]
- [Biur Halacha 233:1]',
    halachic_source = 'Shulchan Aruch OC 233:1'
WHERE key = 'sunrise' AND is_standard = true;

UPDATE zman_definitions
SET halachic_notes = '## Source

צאת הכוכבים is when three medium stars become visible. Different authorities calculate this at different solar depression angles.

### Common Opinions
- **8.5°** - Standard nightfall (approximately 35 minutes after sunset at equatorial latitudes)
- **7.083°** (Rabbeinu Tam minority opinion for certain stringencies)

### References
- [Shulchan Aruch OC 235:1]
- [Mishnah Berurah 235:1]',
    halachic_source = 'Shulchan Aruch OC 235:1'
WHERE key = 'tzeis_hakochavim' AND is_standard = true;

UPDATE zman_definitions
SET halachic_notes = '## Source

עלות השחר marks the beginning of dawn, traditionally defined as when a thread of white can be distinguished from a thread of blue.

### Common Calculations
- **72 minutes** before sunrise (based on seasonal hours)
- **16.1°** below horizon
- **90 minutes** before sunrise (stringent opinion)

### References
- [Shulchan Aruch OC 89:1]
- [Mishnah Berurah 89:2]
- [Biur Halacha "משעלה עמוד השחר"]',
    halachic_source = 'Shulchan Aruch OC 89:1'
WHERE key = 'alos_hashachar' AND is_standard = true;

UPDATE zman_definitions
SET halachic_notes = '## Source

Latest time to recite the morning Shema, calculated as 3 proportional hours into the day.

### Methods
- **GRA** (Vilna Gaon): 3 hours from sunrise to sunset
- **MGA** (Magen Avraham): 3 hours from dawn (72 min before sunrise) to nightfall (72 min after sunset)

### References
- [Shulchan Aruch OC 58:1]
- [Mishnah Berurah 58:1-4]',
    halachic_source = 'Shulchan Aruch OC 58:1'
WHERE key = 'sof_zman_shma' AND is_standard = true;
