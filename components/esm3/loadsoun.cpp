#include "loadsoun.hpp"

#include "esmreader.hpp"
#include "esmwriter.hpp"
#include "components/esm/defs.hpp"

namespace ESM
{
    unsigned int Sound::sRecordId = REC_SOUN;

    void Sound::load(ESMReader &esm, bool &isDeleted)
    {
        isDeleted = false;
        mRecordFlags = esm.getRecordFlags();

        bool hasName = false;
        bool hasData = false;
        while (esm.hasMoreSubs())
        {
            esm.getSubName();
            switch (esm.retSubName().toInt())
            {
                case SREC_NAME:
                    mId = esm.getHString();
                    hasName = true;
                    break;
                case fourCC("FNAM"):
                    mSound = esm.getHString();
                    break;
                case fourCC("DATA"):
                    esm.getHTSized<3>(mData);
                    hasData = true;
                    break;
                case SREC_DELE:
                    esm.skipHSub();
                    isDeleted = true;
                    break;
                default:
                    esm.fail("Unknown subrecord");
                    break;
            }
        }

        if (!hasName)
            esm.fail("Missing NAME subrecord");
        if (!hasData && !isDeleted)
            esm.fail("Missing DATA subrecord");
    }

    void Sound::save(ESMWriter &esm, bool isDeleted) const
    {
        esm.writeHNCString("NAME", mId);

        if (isDeleted)
        {
            esm.writeHNString("DELE", "", 3);
            return;
        }

        esm.writeHNOCString("FNAM", mSound);
        esm.writeHNT("DATA", mData, 3);
    }

    void Sound::blank()
    {
        mSound.clear();

        mData.mVolume = 128;
        mData.mMinRange = 0;
        mData.mMaxRange = 255;
    }
}
