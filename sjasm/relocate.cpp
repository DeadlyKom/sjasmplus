/*

  SjASMPlus Z80 Cross Compiler - modified - RELOCATE extension

  Copyright (c) 2006 Sjoerd Mastijn (original SW)
  Copyright (c) 2020 Peter Ped Helcmanovsky (RELOCATE extension)

  This software is provided 'as-is', without any express or implied warranty.
  In no event will the authors be held liable for any damages arising from the
  use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it freely,
  subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not claim
	 that you wrote the original software. If you use this software in a product,
	 an acknowledgment in the product documentation would be appreciated but is
	 not required.

  2. Altered source versions must be plainly marked as such, and must not be
	 misrepresented as being the original software.

  3. This notice may not be removed or altered from any source distribution.

*/

// relocate.cpp

#include "sjdefs.h"

// local implementation specific data
static TextFilePos startPos;				// sourcefile position of last correct RELOCATE_START
static size_t maxTableCount = 0;			// maximum count of relocation data
static std::vector<word> offsets;			// offsets collected during current pass
static std::vector<word> offsetsPrevious;	// offsets from pass2 (to be exported if pass3 is incomplete)
static bool warnAboutContentChange = false;	// if any change in content between passes should be reported

bool Relocation::isActive = false;			// when inside relocation block
bool Relocation::areLabelsOffset = false;	// when the Labels should return the alternative value
bool Relocation::isResultAffected = false;	// when one of previous expression results was affected by it

// when some part of opcode needs relocation, add its offset to the relocation table
void Relocation::addOffsetToRelocate(const aint offset) {
	// if table was already emitted from previous pass copy, warn about value discrepancies
	if (warnAboutContentChange) {
		const size_t newIndex = offsets.size();
		if (offsetsPrevious.size() <= newIndex || offsetsPrevious[newIndex] != offset) {
			Warning("Relocation table seems internally inconsistent", "table content differs in last pass");
			warnAboutContentChange = false;
		}
	}
	// add new offset to the relocation table
	offsets.push_back(offset);
}

// directives implementation

static void refreshMaxTableCount() {
	if (maxTableCount < offsets.size()) {
		maxTableCount = offsets.size();
	}
	// add the relocate_count and relocate_size symbols only when RELOCATE feature was used
	if (Relocation::isActive || maxTableCount) {
		LabelTable.Insert("relocate_count", maxTableCount, false, true, false);
		LabelTable.Insert("relocate_size", maxTableCount * 2, false, true, false);
	}
}

void Relocation::dirRELOCATE_START() {
	if (isActive) {
		char errTxt[LINEMAX];
		SPRINTF2(errTxt, LINEMAX, "Relocation block already started at: %s(%d)",
				 startPos.filename, startPos.line);
		Error(errTxt);
		return;
	}
	if (PseudoORG) {
		Error("Relocation block can't be used together with DISP");
		return;
	}
	isActive = true;
	startPos = CurSourcePos;
	refreshMaxTableCount();
}

void Relocation::dirRELOCATE_END() {
	if (!isActive) {
		Error("Relocation block start for this end is missing");
		return;
	}
	isActive = false;
	refreshMaxTableCount();
}

void Relocation::dirRELOCATE_TABLE() {
	const bool isLastPass = (LASTPASS == pass);
	warnAboutContentChange = isLastPass;	// don't set it until last pass
	// select which vector will be used to dump offsets into machine code
	// will use the backup copy from previous pass if the current pass seems incomplete (TABLE dumped early)
	auto & dumpOffsets = (offsets.size() < maxTableCount) ? offsetsPrevious : offsets;
	if (isLastPass && dumpOffsets.size() != maxTableCount) {
		Warning("Relocation table seems internally inconsistent", "size differs between passes too much");
	}
	// dump the table into machine code output
	for (const word offset : dumpOffsets) EmitWord(offset);
	// if the current pass table is incomplete, at least warn about discrepancies in values
	if (isLastPass && (offsets.size() < maxTableCount)) {
		for (size_t oi = 0; oi < offsets.size(); ++oi) {
			if (offsets[oi] == offsetsPrevious[oi]) continue;
			Warning("Relocation table seems internally inconsistent", "table content differs in last pass");
			warnAboutContentChange = false;
			break;
		}
	}
}

void Relocation::InitPass() {
	// check if the relocation block is still open (missing RELOCATION_END in source)
	if (isActive) {
		TextFilePos oldCurSourcePos = CurSourcePos;
		CurSourcePos = startPos;
		Error("Missing end of relocation block started here");
		CurSourcePos = oldCurSourcePos;
	}
	// keep copy of final offsets table from previous pass
	offsetsPrevious = offsets;
	// refresh the maximum count, clear the table for next pass and init the state
	refreshMaxTableCount();
	offsets.clear();
	isActive = false;
}

//eof relocate.cpp