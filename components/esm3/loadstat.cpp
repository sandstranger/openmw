#include "loadstat.hpp"

#include "esmreader.hpp"
#include "esmwriter.hpp"

#include <components/settings/settings.hpp>

namespace ESM
{
    void Static::load(ESMReader &esm, bool &isDeleted)
    {
        isDeleted = false;
        mRecordFlags = esm.getRecordFlags();
        //bool isBlocked = (mRecordFlags & FLAG_Blocked) != 0;
        //bool isPersistent = (mRecordFlags & FLAG_Persistent) != 0;

        bool hasName = false;
        while (esm.hasMoreSubs())
        {
            esm.getSubName();
            switch (esm.retSubName().toInt())
            {
                case SREC_NAME:
                    mId = esm.getHString();
                    hasName = true;
                    break;
                case fourCC("MODL"):
                    mModel = esm.getHString();
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

        if(Settings::Manager::getBool("auto use groundcover", "Groundcover") && Settings::Manager::getBool("enabled", "Groundcover"))
        {
            std::string mesh = Misc::StringUtils::lowerCase (mModel);
            if (mesh.find("grass\\") == 0)
                mIsGroundcover = true;
        }
        else
            mIsGroundcover = esm.isGroundcoverFile();
    }
    void Static::save(ESMWriter &esm, bool isDeleted) const
    {
        esm.writeHNCString("NAME", mId);
        if (isDeleted)
        {
            esm.writeHNString("DELE", "", 3);
        }
        else
        {
            esm.writeHNCString("MODL", mModel);
        }
    }

    void Static::blank()
    {
        mRecordFlags = 0;
        mModel.clear();
    }
}
