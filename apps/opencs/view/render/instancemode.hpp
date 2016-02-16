#ifndef CSV_RENDER_INSTANCEMODE_H
#define CSV_RENDER_INSTANCEMODE_H

#include "editmode.hpp"

namespace CSVWidget
{
    class SceneToolMode;
}

namespace CSVRender
{
    class InstanceSelectionMode;

    class InstanceMode : public EditMode
    {
            Q_OBJECT

            enum DragMode
            {
                DragMode_None,
                DragMode_Move

            };

            CSVWidget::SceneToolMode *mSubMode;
            InstanceSelectionMode *mSelectionMode;
            DragMode mDragMode;

        public:

            InstanceMode (WorldspaceWidget *worldspaceWidget, QWidget *parent = 0);

            virtual void activate (CSVWidget::SceneToolbar *toolbar);

            virtual void deactivate (CSVWidget::SceneToolbar *toolbar);

            virtual void primaryEditPressed (osg::ref_ptr<TagBase> tag);

            virtual void secondaryEditPressed (osg::ref_ptr<TagBase> tag);

            virtual void primarySelectPressed (osg::ref_ptr<TagBase> tag);

            virtual void secondarySelectPressed (osg::ref_ptr<TagBase> tag);

            virtual bool primaryEditStartDrag (osg::ref_ptr<TagBase> tag);

            virtual bool secondaryEditStartDrag (osg::ref_ptr<TagBase> tag);

            virtual void drag (int diffX, int diffY, double speedFactor);

            virtual void dragCompleted();

            virtual void dragWheel (int diff, double speedFactor);

            virtual void dragEnterEvent (QDragEnterEvent *event);

            virtual void dropEvent (QDropEvent* event);
    };
}

#endif
