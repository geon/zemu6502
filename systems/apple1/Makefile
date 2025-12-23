SOURCES = wozmon-rom.s
WOZMON_ROM = wozmon-rom.bin

all: $(WOZMON_ROM)

clean:
	rm -f *.o
	rm -f *.lst
	rm -f *.map
	rm -f *.bin

%.o: %.s
	ca65 --listing $(@F).lst -o $@ $<

$(WOZMON_ROM)2: $(SOURCES:.s=.o)
	ld65 -C apple1.cfg -m $(@).map -o $@ $^

	@echo
	@echo Image size:
	@stat -c "%s bytes" $(@)


VASM=vasm6502_oldstyle
AFLAGS=-Fbin -dotdir

$(WOZMON_ROM): wozmon-rom.asm
	echo Building image: $(@)
	$(VASM) $(AFLAGS) -L $(@D)/$(@F).lst -o $(@) $<

	@echo
	@echo Image size:
	@stat -c "%s bytes" $(@)
