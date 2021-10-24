#include "loadpgrd.hpp"

#include "esmreader.hpp"
#include "esmwriter.hpp"
#include "defs.hpp"

namespace ESM
{
    unsigned int Pathgrid::sRecordId = REC_PGRD;

    Pathgrid::Point& Pathgrid::Point::operator=(const float rhs[3])
    {
        mX = static_cast<int>(rhs[0]);
        mY = static_cast<int>(rhs[1]);
        mZ = static_cast<int>(rhs[2]);
        mAutogenerated = 0;
        mConnectionNum = 0;
        mUnknown = 0;
        return *this;
    }
    Pathgrid::Point::Point(const float rhs[3])
    : mX(static_cast<int>(rhs[0])),
      mY(static_cast<int>(rhs[1])),
      mZ(static_cast<int>(rhs[2])),
      mAutogenerated(0),
      mConnectionNum(0),
      mUnknown(0)
    {
    }
    Pathgrid::Point::Point():mX(0),mY(0),mZ(0),mAutogenerated(0),
                             mConnectionNum(0),mUnknown(0)
    {
    }

    void Pathgrid::load(ESMReader &esm, bool &isDeleted)
    {
        isDeleted = false;

        mPoints.clear();
        mEdges.clear();

        // keep track of total connections so we can reserve edge vector size
        int edgeCount = 0;

        bool hasData = false;
        while (esm.hasMoreSubs())
        {
            esm.getSubName();
            switch (esm.retSubName().toInt())
            {
                case ESM::SREC_NAME:
                    mCell = esm.getHString();
                    break;
                case ESM::FourCC<'D','A','T','A'>::value:
                    esm.getHT(mData, 12);
                    hasData = true;
                    break;
                case ESM::FourCC<'P','G','R','P'>::value:
                {
                    esm.getSubHeader();
                    int size = esm.getSubSize();
                    // Check that the sizes match up. Size = 16 * s2 (path points)
                    if (size != static_cast<int> (sizeof(Point) * mData.mS2))
                        esm.fail("Path point subrecord size mismatch");
                    else
                    {
                        int pointCount = mData.mS2;
                        mPoints.reserve(pointCount);
                        for (int i = 0; i < pointCount; ++i)
                        {
                            Point p;
                            esm.getExact(&p, sizeof(Point));
                            mPoints.push_back(p);
                            edgeCount += p.mConnectionNum;
                        }
                    }
                    break;
                }
                case ESM::FourCC<'P','G','R','C'>::value:
                {
                    esm.getSubHeader();
                    int size = esm.getSubSize();
                    if (size % sizeof(int) != 0)
                        esm.fail("PGRC size not a multiple of 4");
                    else
                    {
                        int rawConnNum = size / sizeof(int);
                        std::vector<int> rawConnections;
                        rawConnections.reserve(rawConnNum);
                        for (int i = 0; i < rawConnNum; ++i)
                        {
                            int currentValue;
                            esm.getT(currentValue);
                            rawConnections.push_back(currentValue);
                        }

                        std::vector<int>::const_iterator rawIt = rawConnections.begin();
                        int pointIndex = 0;
                        mEdges.reserve(edgeCount);
                        for(PointList::const_iterator it = mPoints.begin(); it != mPoints.end(); ++it, ++pointIndex)
                        {
                            unsigned char connectionNum = (*it).mConnectionNum;
                            if (rawConnections.end() - rawIt < connectionNum)
                                esm.fail("Not enough connections");
                            for (int i = 0; i < connectionNum; ++i) {
                                Edge edge;
                                edge.mV0 = pointIndex;
                                edge.mV1 = *rawIt;
                                ++rawIt;
                                mEdges.push_back(edge);
                            }
                        }
                    }
                    break;
                }
                case ESM::SREC_DELE:
                    esm.skipHSub();
                    isDeleted = true;
                    break;
                default:
                    esm.fail("Unknown subrecord");
                    break;
            }
        }

        if (!hasData)
            esm.fail("Missing DATA subrecord");
    }

    void Pathgrid::save(ESMWriter &esm, bool isDeleted) const
    {
        // Correct connection count and sort edges by point
        // Can probably be optimized
        PointList correctedPoints = mPoints;
        std::vector<int> sortedEdges;

        sortedEdges.reserve(mEdges.size());

        for (size_t point = 0; point < correctedPoints.size(); ++point)
        {
            correctedPoints[point].mConnectionNum = 0;

            for (EdgeList::const_iterator it = mEdges.begin(); it != mEdges.end(); ++it)
            {
                if (static_cast<size_t>(it->mV0) == point)
                {
                    sortedEdges.push_back(it->mV1);
                    ++correctedPoints[point].mConnectionNum;
                }
            }
        }

        // Save
        esm.writeHNCString("NAME", mCell);
        esm.writeHNT("DATA", mData, 12);

        if (isDeleted)
        {
            esm.writeHNString("DELE", "", 3);
            return;
        }

        if (!correctedPoints.empty())
        {
            esm.startSubRecord("PGRP");
            for (PointList::const_iterator it = correctedPoints.begin(); it != correctedPoints.end(); ++it)
            {
                esm.writeT(*it);
            }
            esm.endRecord("PGRP");
        }

        if (!sortedEdges.empty())
        {
            esm.startSubRecord("PGRC");
            for (std::vector<int>::const_iterator it = sortedEdges.begin(); it != sortedEdges.end(); ++it)
            {
                esm.writeT(*it);
            }
            esm.endRecord("PGRC");
        }
    }

    void Pathgrid::blank()
    {
        mCell.clear();
        mData.mX = 0;
        mData.mY = 0;
        mData.mS1 = 0;
        mData.mS2 = 0;
        mPoints.clear();
        mEdges.clear();
    }
}
