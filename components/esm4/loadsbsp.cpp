/*
  Copyright (C) 2016, 2018, 2020 cc9cii

  This software is provided 'as-is', without any express or implied
  warranty.  In no event will the authors be held liable for any damages
  arising from the use of this software.

  Permission is granted to anyone to use this software for any purpose,
  including commercial applications, and to alter it and redistribute it
  freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented; you must not
     claim that you wrote the original software. If you use this software
     in a product, an acknowledgment in the product documentation would be
     appreciated but is not required.
  2. Altered source versions must be plainly marked as such, and must not be
     misrepresented as being the original software.
  3. This notice may not be removed or altered from any source distribution.

  cc9cii cc9c@iinet.net.au

  Much of the information on the data structures are based on the information
  from Tes4Mod:Mod_File_Format and Tes5Mod:File_Formats but also refined by
  trial & error.  See http://en.uesp.net/wiki for details.

*/
#include "loadsbsp.hpp"

#include <stdexcept>

#include "reader.hpp"
//#include "writer.hpp"

ESM4::SubSpace::SubSpace() : mFormId(0), mFlags(0)
{
    mEditorId.clear();

    mDimension.x = 0.f;
    mDimension.y = 0.f;
    mDimension.z = 0.f;
}

ESM4::SubSpace::~SubSpace()
{
}

void ESM4::SubSpace::load(ESM4::Reader& reader)
{
    mFormId = reader.hdr().record.id;
    reader.adjustFormId(mFormId);
    mFlags  = reader.hdr().record.flags;

    while (reader.getSubRecordHeader())
    {
        const ESM4::SubRecordHeader& subHdr = reader.subRecordHeader();
        switch (subHdr.typeId)
        {
            case ESM4::SUB_EDID: reader.getZString(mEditorId); break;
            case ESM4::SUB_DNAM:
            {
                reader.get(mDimension.x);
                reader.get(mDimension.y);
                reader.get(mDimension.z);
                break;
            }
            default:
                throw std::runtime_error("ESM4::SBSP::load - Unknown subrecord " + ESM::printName(subHdr.typeId));
        }
    }
}

//void ESM4::SubSpace::save(ESM4::Writer& writer) const
//{
//}

//void ESM4::SubSpace::blank()
//{
//}
