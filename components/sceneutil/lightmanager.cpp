#include "lightmanager.hpp"

#include <osg/BufferObject>
#include <osg/BufferIndexBinding>

#include <osgUtil/CullVisitor>

#include <components/sceneutil/util.hpp>

#include <components/misc/stringops.hpp>

#include <components/settings/settings.hpp>

#include <components/debug/debuglog.hpp>

#include "apps/openmw/mwrender/vismask.hpp"

namespace 
{
    /* similar to the boost::hash_combine */
    template <class T>
    inline void hash_combine(std::size_t& seed, const T& v)
    {
        std::hash<T> hasher;
        seed ^= hasher(v) + 0x9e3779b9 + (seed<<6) + (seed>>2);
    }

    bool sortLights(const SceneUtil::LightManager::LightSourceViewBound* left, const SceneUtil::LightManager::LightSourceViewBound* right)
    {
        return left->mViewBound.center().length2() - left->mViewBound.radius2()*81 < right->mViewBound.center().length2() - right->mViewBound.radius2()*81;
    }

    float getLightRadius(const osg::Light* light)
    {
        float value = 0.0;
        light->getUserValue("radius", value);
        return value;
    }

    void setLightRadius(osg::Light* light, float value)
    {
        light->setUserValue("radius", value);
    }
}

namespace SceneUtil
{
    static int sLightId = 0;

////////////////////////////////////////////////////////////////////////////////
// Internal Data Structures
////////////////////////////////////////////////////////////////////////////////

    class SunLightBuffer : public osg::Referenced
    {
    public:
        SunLightBuffer() : mData(new osg::Vec4Array(4)) {}

        void setDiffuse(const osg::Vec4& value)
        {
            (*mData)[0] = value;
        }

        void setAmbient(const osg::Vec4& value)
        {
            (*mData)[1] = value;
        }

        void setSpecular(const osg::Vec4& value)
        {
            (*mData)[2] = value;
        }

        void setDirection(const osg::Vec4& value)
        {
            (*mData)[3] = value;
        }

        osg::ref_ptr<osg::Vec4Array> mData;
    };


    class PointLightBuffer : public osg::Referenced
    {
    public:

        PointLightBuffer(int count) : mData(new osg::Vec4Array(4*count)), mOriginPosition(count) {}

        void setPosition(int index, const osg::Vec4& value)
        {
            (*mData)[4*index+0] = value;
        }

        void setDiffuse(int index, const osg::Vec4& value)
        {
            (*mData)[4*index+1] = value;
        }

        void setAmbient(int index, const osg::Vec4& value)
        {
            (*mData)[4*index+2] = value;
        }

        void setAttenuation(int index, float c, float l, float q)
        {
            (*mData)[4*index+3][0] = c;
            (*mData)[4*index+3][1] = l;
            (*mData)[4*index+3][2] = q;
        }

        void setRadius(int index, float value)
        {
            (*mData)[4*index+3][3] = value;
        }

        void setOriginPosition(int index, const osg::Vec4& light)
        {
            mOriginPosition[index] = light;
        }

        auto getPosition(int index)
        {
            return (*mData)[4*index+0];
        }

        auto getOriginPosition(int index)
        {
            return mOriginPosition[index];
        }

        auto& getData() { return mData; }
        void dirty() { mData->dirty(); }

        static constexpr int queryBlockSize(int sz)
        {
            return 4 * osg::Vec4::num_components * sizeof(GL_FLOAT) * sz;
        }

        osg::ref_ptr<osg::Vec4Array> mData;
        std::vector<osg::Vec4> mOriginPosition;
    };

    class LightStateCache
    {
    public:
        std::vector<osg::Light*> lastAppliedLight;
    };

    LightStateCache* getLightStateCache(size_t contextid, size_t size = 8)
    {
        static std::vector<LightStateCache> cacheVector;
        if (cacheVector.size() < contextid+1)
            cacheVector.resize(contextid+1);
        cacheVector[contextid].lastAppliedLight.resize(size);
        return &cacheVector[contextid];
    }

////////////////////////////////////////////////////////////////////////////////
// State Attributes
////////////////////////////////////////////////////////////////////////////////


    void configureStateSetSunOverride(LightingMethod method, const osg::Light* light, osg::StateSet* stateset, int mode)
    {
        switch (method)
        {
        case LightingMethod::FFP:
            break;
        case LightingMethod::PerObjectUniform:
        {
            stateset->addUniform(new osg::Uniform("Sun.diffuse", light->getDiffuse()), mode);
            stateset->addUniform(new osg::Uniform("Sun.ambient", light->getAmbient()), mode);
            stateset->addUniform(new osg::Uniform("Sun.specular", light->getSpecular()), mode);
            stateset->addUniform(new osg::Uniform("Sun.direction", light->getPosition()), mode);

            break;
        }
        case LightingMethod::SingleUBO:
        {
            osg::ref_ptr<SunLightBuffer> buffer = new SunLightBuffer;

            buffer->setDiffuse(light->getDiffuse());
            buffer->setAmbient(light->getAmbient());
            buffer->setSpecular(light->getSpecular());
            buffer->setDirection(light->getPosition());

            osg::ref_ptr<osg::UniformBufferObject> ubo = new osg::UniformBufferObject;
            buffer->mData->setBufferObject(ubo);
            osg::ref_ptr<osg::UniformBufferBinding> ubb = new osg::UniformBufferBinding(static_cast<int>(Shader::UBOBinding::SunLightBuffer), buffer->mData.get(), 0, buffer->mData->getTotalDataSize());

            stateset->setAttributeAndModes(ubb, mode);

            break;
        }
        }
    }

    class DisableLight : public osg::StateAttribute
    {
    public:
        DisableLight() : mIndex(0) {}
        DisableLight(int index) : mIndex(index) {}

        DisableLight(const DisableLight& copy,const osg::CopyOp& copyop=osg::CopyOp::SHALLOW_COPY)
            : osg::StateAttribute(copy,copyop), mIndex(copy.mIndex) {}

        osg::Object* cloneType() const override { return new DisableLight(mIndex); }
        osg::Object* clone(const osg::CopyOp& copyop) const override { return new DisableLight(*this,copyop); }
        bool isSameKindAs(const osg::Object* obj) const override { return dynamic_cast<const DisableLight *>(obj)!=nullptr; }
        const char* libraryName() const override { return "SceneUtil"; }
        const char* className() const override { return "DisableLight"; }
        Type getType() const override { return LIGHT; }

        unsigned int getMember() const override
        {
            return mIndex;
        }

        bool getModeUsage(ModeUsage & usage) const override
        {
            usage.usesMode(GL_LIGHT0 + mIndex);
            return true;
        }

        int compare(const StateAttribute &sa) const override
        {
            throw std::runtime_error("DisableLight::compare: unimplemented");
        }

        void apply(osg::State& state) const override
        {
            int lightNum = GL_LIGHT0 + mIndex;
            glLightfv( lightNum, GL_AMBIENT,               mnullptr.ptr() );
            glLightfv( lightNum, GL_DIFFUSE,               mnullptr.ptr() );
            glLightfv( lightNum, GL_SPECULAR,              mnullptr.ptr() );

            LightStateCache* cache = getLightStateCache(state.getContextID());
            cache->lastAppliedLight[mIndex] = nullptr;
        }

    private:
        size_t mIndex;
        osg::Vec4f mnullptr;
    };

    class FFPLightStateAttribute : public osg::StateAttribute
    {
    public:
        FFPLightStateAttribute() : mIndex(0) {}
        FFPLightStateAttribute(size_t index, const std::vector<osg::ref_ptr<osg::Light> >& lights) : mIndex(index), mLights(lights) {}

        FFPLightStateAttribute(const FFPLightStateAttribute& copy,const osg::CopyOp& copyop=osg::CopyOp::SHALLOW_COPY)
            : osg::StateAttribute(copy,copyop), mIndex(copy.mIndex), mLights(copy.mLights) {}

        unsigned int getMember() const override
        {
            return mIndex;
        }

        bool getModeUsage(ModeUsage & usage) const override
        {
            for (size_t i=0; i<mLights.size(); ++i)
                usage.usesMode(GL_LIGHT0 + mIndex + i);
            return true;
        }

        int compare(const StateAttribute &sa) const override
        {
            throw std::runtime_error("FFPLightStateAttribute::compare: unimplemented");
        }

        META_StateAttribute(NifOsg, FFPLightStateAttribute, osg::StateAttribute::LIGHT)

        void apply(osg::State& state) const override
        {
            if (mLights.empty())
                return;
            osg::Matrix modelViewMatrix = state.getModelViewMatrix();

            state.applyModelViewMatrix(state.getInitialViewMatrix());

            LightStateCache* cache = getLightStateCache(state.getContextID());

            for (size_t i=0; i<mLights.size(); ++i)
            {
                osg::Light* current = cache->lastAppliedLight[i+mIndex];
                if (current != mLights[i].get())
                {
                    applyLight((GLenum)((int)GL_LIGHT0 + i + mIndex), mLights[i].get());
                    cache->lastAppliedLight[i+mIndex] = mLights[i].get();
                }
            }

            state.applyModelViewMatrix(modelViewMatrix);
        }

        void applyLight(GLenum lightNum, const osg::Light* light) const
        {
            glLightfv( lightNum, GL_AMBIENT,               light->getAmbient().ptr() );
            glLightfv( lightNum, GL_DIFFUSE,               light->getDiffuse().ptr() );
            glLightfv( lightNum, GL_SPECULAR,              light->getSpecular().ptr() );
            glLightfv( lightNum, GL_POSITION,              light->getPosition().ptr() );
            // TODO: enable this once spot lights are supported
            // need to transform SPOT_DIRECTION by the world matrix?
            //glLightfv( lightNum, GL_SPOT_DIRECTION,        light->getDirection().ptr() );
            //glLightf ( lightNum, GL_SPOT_EXPONENT,         light->getSpotExponent() );
            //glLightf ( lightNum, GL_SPOT_CUTOFF,           light->getSpotCutoff() );
            glLightf ( lightNum, GL_CONSTANT_ATTENUATION,  light->getConstantAttenuation() );
            glLightf ( lightNum, GL_LINEAR_ATTENUATION,    light->getLinearAttenuation() );
            glLightf ( lightNum, GL_QUADRATIC_ATTENUATION, light->getQuadraticAttenuation() );
        }

    private:
        size_t mIndex;

        std::vector<osg::ref_ptr<osg::Light>> mLights;
    };

    LightManager* findLightManager(const osg::NodePath& path)
    {
        for (size_t i=0;i<path.size(); ++i)
        {
            if (LightManager* lightManager = dynamic_cast<LightManager*>(path[i]))
                return lightManager;
        }
        return nullptr;
    }

    struct StateSetGeneratorPerObjectUniform;

    class LightStateAttributePerObjectUniform : public osg::StateAttribute
    {
    public:
        LightStateAttributePerObjectUniform() {}
        LightStateAttributePerObjectUniform(const std::vector<osg::ref_ptr<osg::Light>>& lights, LightManager* lightManager) :  mLights(lights), mLightManager(lightManager) {}

        LightStateAttributePerObjectUniform(const LightStateAttributePerObjectUniform& copy,const osg::CopyOp& copyop=osg::CopyOp::SHALLOW_COPY)
            : osg::StateAttribute(copy,copyop), mLights(copy.mLights), mLightManager(copy.mLightManager) {}

        int compare(const StateAttribute &sa) const override
        {
            throw std::runtime_error("LightStateAttributePerObjectUniform::compare: unimplemented");
        }

        META_StateAttribute(NifOsg, LightStateAttributePerObjectUniform, osg::StateAttribute::LIGHT)

        void apply(osg::State &state) const override
        {

            osg::Matrix modelViewMatrix = state.getModelViewMatrix();

            state.applyModelViewMatrix(state.getInitialViewMatrix());

            LightStateCache* cache = getLightStateCache(state.getContextID(), mLightManager->getMaxLights());
            for (size_t i = 0; i < mLights.size(); ++i)
            {
                osg::Light* current = cache->lastAppliedLight[i];
                auto light = mLights[i];
                if (current != light.get())
                {
                    mLightManager->getLightUniform(i, LightManager::UniformKey::Diffuse)->set(light->getDiffuse());
                    mLightManager->getLightUniform(i, LightManager::UniformKey::Ambient)->set(light->getAmbient());
                    mLightManager->getLightUniform(i, LightManager::UniformKey::Attenuation)->set(osg::Vec4(light->getConstantAttenuation(), light->getLinearAttenuation(), light->getQuadraticAttenuation(), getLightRadius(light)));
                    mLightManager->getLightUniform(i, LightManager::UniformKey::Position)->set(light->getPosition() * state.getModelViewMatrix());

                    cache->lastAppliedLight[i] = mLights[i];
                }
            }
            
            state.applyModelViewMatrix(modelViewMatrix);
        }

    private:
        std::vector<osg::ref_ptr<osg::Light>> mLights;
        LightManager* mLightManager;
    };

    struct StateSetGenerator
    {  
        LightManager* mLightManager;

        virtual ~StateSetGenerator() {}

        virtual osg::ref_ptr<osg::StateSet> generate(const LightManager::LightList& lightList, size_t frameNum) = 0;

        virtual void update(osg::StateSet* stateset, const LightManager::LightList& lightList, size_t frameNum) {}
    };

    struct StateSetGeneratorFFP : StateSetGenerator
    {
        osg::ref_ptr<osg::StateSet> generate(const LightManager::LightList& lightList, size_t frameNum) override
        {
            osg::ref_ptr<osg::StateSet> stateset = new osg::StateSet;

            std::vector<osg::ref_ptr<osg::Light>> lights;
            lights.reserve(lightList.size());
            for (size_t i = 0; i < lightList.size(); ++i)
                lights.emplace_back(lightList[i]->mLightSource->getLight(frameNum));

            // the first light state attribute handles the actual state setting for all lights
            // it's best to batch these up so that we don't need to touch the modelView matrix more than necessary
            // don't use setAttributeAndModes, that does not support light indices!
            stateset->setAttribute(new FFPLightStateAttribute(mLightManager->getStartLight(), std::move(lights)), osg::StateAttribute::ON);

            for (size_t i = 0; i < lightList.size(); ++i)
                stateset->setMode(GL_LIGHT0 + mLightManager->getStartLight() + i, osg::StateAttribute::ON);

            // need to push some dummy attributes to ensure proper state tracking
            // lights need to reset to their default when the StateSet is popped
            for (size_t i = 1; i < lightList.size(); ++i)
                stateset->setAttribute(mLightManager->getDummies()[i + mLightManager->getStartLight()].get(), osg::StateAttribute::ON);

            return stateset;
        }
    };

    struct StateSetGeneratorSingleUBO : StateSetGenerator
    {
        osg::ref_ptr<osg::StateSet> generate(const LightManager::LightList& lightList, size_t frameNum) override
        {
            osg::ref_ptr<osg::StateSet> stateset = new osg::StateSet;

            osg::ref_ptr<osg::IntArray> indices = new osg::IntArray(mLightManager->getMaxLights());
            osg::ref_ptr<osg::Uniform> indicesUni = new osg::Uniform(osg::Uniform::Type::INT, "PointLightIndex", indices->size());
            int pointCount = 0;

            for (size_t i = 0; i < lightList.size(); ++i)
            {
                int bufIndex = mLightManager->getLightData(frameNum)[lightList[i]->mLightSource->getId()];
                indices->at(pointCount++) = bufIndex;
            }
            indicesUni->setArray(indices);
            stateset->addUniform(indicesUni);
            stateset->addUniform(new osg::Uniform("PointLightCount", pointCount));

            return stateset;
        }

        // Cached statesets must be re-validated in case the light indicies change. There is no actual link between
        // a lights ID and the buffer index it will eventually be assigned (or reassigned) to.
        void update(osg::StateSet* stateset, const LightManager::LightList& lightList, size_t frameNum) override
        {
            int newCount = 0;
            int oldCount;

            auto uOldArray = stateset->getUniform("PointLightIndex");
            auto uOldCount = stateset->getUniform("PointLightCount");

            uOldCount->get(oldCount);

            auto& lightData = mLightManager->getLightData(frameNum);

            for (int i = 0; i < oldCount; ++i)
            {
                auto* lightSource = lightList[i]->mLightSource;
                auto it = lightData.find(lightSource->getId());
                if (it != lightData.end())
                    uOldArray->setElement(newCount++, it->second);
            }

            uOldArray->dirty();
            uOldCount->set(newCount);
        }
    };

    struct StateSetGeneratorPerObjectUniform : StateSetGenerator
    {
        osg::ref_ptr<osg::StateSet> generate(const LightManager::LightList& lightList, size_t frameNum) override
        {
            osg::ref_ptr<osg::StateSet> stateset = new osg::StateSet;

            std::vector<osg::ref_ptr<osg::Light>> lights(lightList.size());

            for (size_t i = 0; i < lightList.size(); ++i)
            {
                auto* light = lightList[i]->mLightSource->getLight(frameNum);
                lights[i] = light;
                setLightRadius(light, lightList[i]->mLightSource->getRadius() * 0.5);
            }

            stateset->setAttributeAndModes(new LightStateAttributePerObjectUniform(std::move(lights), mLightManager), osg::StateAttribute::ON);

            stateset->addUniform(new osg::Uniform("PointLightCount", static_cast<int>(lightList.size())));

            return stateset;
        }
    };

////////////////////////////////////////////////////////////////////////////////
// Node Callbacks
////////////////////////////////////////////////////////////////////////////////

    // Set on a LightSource. Adds the light source to its light manager for the current frame.
    // This allows us to keep track of the current lights in the scene graph without tying creation & destruction to the manager.
    class CollectLightCallback : public osg::NodeCallback
    {
    public:
        CollectLightCallback()
            : mLightManager(nullptr) { }

        CollectLightCallback(const CollectLightCallback& copy, const osg::CopyOp& copyop)
            : osg::NodeCallback(copy, copyop)
            , mLightManager(nullptr) { }

        META_Object(SceneUtil, SceneUtil::CollectLightCallback)

        void operator()(osg::Node* node, osg::NodeVisitor* nv) override
        {
            if (!mLightManager)
            {
                mLightManager = findLightManager(nv->getNodePath());

                if (!mLightManager)
                    throw std::runtime_error("can't find parent LightManager");                
            }
            
            mLightManager->addLight(static_cast<LightSource*>(node), osg::computeLocalToWorld(nv->getNodePath()), nv->getTraversalNumber());

            traverse(node, nv);
        }

    private:
        LightManager* mLightManager;
    };

    // Set on a LightManager. Clears the data from the previous frame.
    class LightManagerUpdateCallback : public osg::NodeCallback
    {
    public:
        LightManagerUpdateCallback()
            { }

        LightManagerUpdateCallback(const LightManagerUpdateCallback& copy, const osg::CopyOp& copyop)
            : osg::NodeCallback(copy, copyop)
            { }

        META_Object(SceneUtil, LightManagerUpdateCallback)

        void operator()(osg::Node* node, osg::NodeVisitor* nv) override
        {
            LightManager* lightManager = static_cast<LightManager*>(node);
            lightManager->update(nv->getTraversalNumber());

            traverse(node, nv);
        }
    };

    class SunlightCallback : public osg::NodeCallback
    {
    public:
        SunlightCallback(LightManager* lightManager) : mLightManager(lightManager) {}

        void operator()(osg::Node* node, osg::NodeVisitor* nv) override
        {
            osgUtil::CullVisitor* cv = static_cast<osgUtil::CullVisitor*>(nv);

            if (mLastFrameNumber != cv->getTraversalNumber())
            {
                mLastFrameNumber = cv->getTraversalNumber();

                auto sun = mLightManager->getSunlight();

                if (mLightManager->getLightingMethod() == LightingMethod::SingleUBO)
                {   
                    auto stateset = mLightManager->getStateSet();
                    auto bo = mLightManager->mPointBufferMapped[mLastFrameNumber%2];
                    osg::ref_ptr<osg::UniformBufferBinding> ubb = new osg::UniformBufferBinding(static_cast<int>(Shader::UBOBinding::PointLightBuffer), bo->getData().get(), 0, bo->getData()->getTotalDataSize());
                    stateset->setAttributeAndModes(ubb.get(), osg::StateAttribute::ON);
                }

                if (!sun)
                    return;

                if (mLightManager->getLightingMethod() == LightingMethod::PerObjectUniform)
                {
                    auto ss = mLightManager->getOrCreateStateSet();
                    ss->getUniform("Sun.diffuse")->set(sun->getDiffuse());
                    ss->getUniform("Sun.ambient")->set(sun->getAmbient());
                    ss->getUniform("Sun.specular")->set(sun->getSpecular());
                    ss->getUniform("Sun.direction")->set(sun->getPosition() * (*cv->getCurrentRenderStage()->getInitialViewMatrix()));
                }
                else
                {
                    auto buf = mLightManager->getSunBuffer();

                    buf->setDiffuse(sun->getDiffuse());
                    buf->setAmbient(sun->getAmbient());
                    buf->setSpecular(sun->getSpecular());
                    buf->setDirection(sun->getPosition() * (*cv->getCurrentRenderStage()->getInitialViewMatrix()));                           

                    buf->mData->dirty();
                }
            }

            traverse(node, nv);
        }

    private:
        LightManager* mLightManager;
        size_t mLastFrameNumber;
    };
    
    class LightManagerStateAttribute : public osg::StateAttribute
    {
    public:
        LightManagerStateAttribute() : mLightManager(nullptr) {}
        LightManagerStateAttribute(LightManager* lightManager) : mLightManager(lightManager) {} 

        LightManagerStateAttribute(const LightManagerStateAttribute& copy,const osg::CopyOp& copyop=osg::CopyOp::SHALLOW_COPY)
            : osg::StateAttribute(copy,copyop),mLightManager(copy.mLightManager) {}

        int compare(const StateAttribute &sa) const override
        {
            throw std::runtime_error("LightManagerStateAttribute::compare: unimplemented");
        }

        META_StateAttribute(NifOsg, LightManagerStateAttribute, osg::StateAttribute::LIGHT)

        void apply(osg::State& state) const override
        {
            int frameIndex = state.getFrameStamp()->getFrameNumber()%2;
            osg::Matrix modelViewMatrix = state.getModelViewMatrix();

            state.applyModelViewMatrix(state.getInitialViewMatrix());
            
            for (const auto& indices : mLightManager->getLightData(state.getFrameStamp()->getFrameNumber()))
            {
                auto pos = mLightManager->mPointBufferMapped[frameIndex]->getOriginPosition(indices.second);
                mLightManager->mPointBufferMapped[frameIndex]->setPosition(indices.second, pos * state.getModelViewMatrix());
            }

            mLightManager->mPointBufferMapped[frameIndex]->dirty();

            state.applyModelViewMatrix(modelViewMatrix);
        }

        LightManager* mLightManager;
    };

    bool LightManager::isValidLightingModelString(const std::string& value)
    {
        static const std::unordered_set<std::string> validLightingModels = {"legacy", "default", "experimental"};
        return validLightingModels.count(value) != 0;
    }

    LightManager::LightManager(bool ffp)
        : mStartLight(0)
        , mLightingMask(~0u)
        , mSun(nullptr)
        , mSunBuffer(nullptr)
    {
        auto lightingModelString = Settings::Manager::getString("lighting method", "Shaders");
        bool validLightingModel = isValidLightingModelString(lightingModelString);
        if (!validLightingModel)
            Log(Debug::Error)   << "Invalid option for 'lighting model':  got '" << lightingModelString 
                                << "',  expected legacy, default, or experimental.";

        if (ffp || !validLightingModel)
        {
            setLightingMethod(LightingMethod::FFP);
            for (int i=0; i<getMaxLights(); ++i)
                mDummies.push_back(new FFPLightStateAttribute(i, std::vector<osg::ref_ptr<osg::Light> >()));
            setUpdateCallback(new LightManagerUpdateCallback);
            return;
        }

        osg::GLExtensions* exts = osg::GLExtensions::Get(0, false);
        bool supportsUBO = exts && exts->isUniformBufferObjectSupported;    
        auto* stateset = getOrCreateStateSet();

        if (!supportsUBO)
            Log(Debug::Info) << "GL_ARB_uniform_buffer_object not supported:  using fallback uniforms"; 

        if (!supportsUBO || Settings::Manager::getString("lighting method", "Shaders") == "default")
        {
            setLightingMethod(LightingMethod::PerObjectUniform);
            
            mLightUniforms.resize(getMaxLights());
            for (size_t i = 0; i < mLightUniforms.size(); ++i)
            {
                osg::ref_ptr<osg::Uniform> udiffuse = new osg::Uniform(osg::Uniform::FLOAT_VEC4, ("PointLights[" + std::to_string(i) + "].diffuse").c_str());
                osg::ref_ptr<osg::Uniform> uambient = new osg::Uniform(osg::Uniform::FLOAT_VEC4, ("PointLights[" + std::to_string(i) + "].ambient").c_str());
                osg::ref_ptr<osg::Uniform> uposition = new osg::Uniform(osg::Uniform::FLOAT_VEC4, ("PointLights[" + std::to_string(i) + "].position").c_str());
                osg::ref_ptr<osg::Uniform> uattenuation = new osg::Uniform(osg::Uniform::FLOAT_VEC4, ("PointLights[" + std::to_string(i) + "].attenuation").c_str());
                
                mLightUniforms[i].emplace(UniformKey::Diffuse, udiffuse);
                mLightUniforms[i].emplace(UniformKey::Ambient, uambient);
                mLightUniforms[i].emplace(UniformKey::Position, uposition);
                mLightUniforms[i].emplace(UniformKey::Attenuation, uattenuation);

                stateset->addUniform(udiffuse);
                stateset->addUniform(uambient);
                stateset->addUniform(uposition);
                stateset->addUniform(uattenuation);
            }

            stateset->addUniform(new osg::Uniform(osg::Uniform::FLOAT_VEC4, "Sun.diffuse"));
            stateset->addUniform(new osg::Uniform(osg::Uniform::FLOAT_VEC4, "Sun.ambient"));
            stateset->addUniform(new osg::Uniform(osg::Uniform::FLOAT_VEC4, "Sun.specular"));
            stateset->addUniform(new osg::Uniform(osg::Uniform::FLOAT_VEC4, "Sun.direction"));
        }
        else
        {
            mSunBuffer = new SunLightBuffer();
            osg::ref_ptr<osg::UniformBufferObject> ubo = new osg::UniformBufferObject;
            ubo->setUsage(GL_DYNAMIC_DRAW);
            mSunBuffer->mData->setBufferObject(ubo);
            osg::ref_ptr<osg::UniformBufferBinding> ubb = new osg::UniformBufferBinding(static_cast<int>(Shader::UBOBinding::SunLightBuffer), mSunBuffer->mData, 0, mSunBuffer->mData->getTotalDataSize());
            stateset->setAttributeAndModes(ubb.get(), osg::StateAttribute::ON);

            setLightingMethod(LightingMethod::SingleUBO);

            for (int i = 0; i < 2; ++i)
            {
                mPointBufferMapped[i] = new PointLightBuffer(getMaxLightsInScene());
                osg::ref_ptr<osg::UniformBufferObject> ubo = new osg::UniformBufferObject;
                ubo->setUsage(GL_STREAM_DRAW);

                mPointBufferMapped[i]->getData()->setBufferObject(ubo);
            }

            stateset->setAttribute(new LightManagerStateAttribute(this), osg::StateAttribute::ON);
        }
        
        stateset->addUniform(new osg::Uniform("PointLightCount", 0));

        setUpdateCallback(new LightManagerUpdateCallback);
        addCullCallback(new SunlightCallback(this));
    }

////////////////////////////////////////////////////////////////////////////////

    LightManager::LightManager(const LightManager &copy, const osg::CopyOp &copyop)
        : osg::Group(copy, copyop)
        , mStartLight(copy.mStartLight)
        , mLightingMask(copy.mLightingMask)
        , mSun(copy.mSun)
        , mSunBuffer(copy.mSunBuffer)
        , mLightingMethod(copy.mLightingMethod)
    {
    }

    LightingMethod LightManager::getLightingMethod() const
    {
        return mLightingMethod;
    }

    bool LightManager::usingFFP() const
    {
        return mLightingMethod == LightingMethod::FFP;
    }

    int LightManager::getMaxLights() const
    {
        if (usingFFP()) return LightManager::mFFPMaxLights;
        return std::clamp(Settings::Manager::getInt("max lights", "Shaders"), 1, getMaxLightsInScene());
    }
    
    int LightManager::getMaxLightsInScene() const
    {
        static constexpr int max = 16384 / PointLightBuffer::queryBlockSize(1);        
        return  max;
    }

    Shader::ShaderManager::DefineMap LightManager::getLightDefines() const
    {
        Shader::ShaderManager::DefineMap defines;

        bool ffp = usingFFP();
        
        defines["ffpLighting"] = ffp ? "1" : "0";
        defines["sunDirection"] = ffp ? "gl_LightSource[0].position" : "Sun.direction";
        defines["sunAmbient"] = ffp ? "gl_LightSource[0].ambient" : "Sun.ambient";
        defines["sunDiffuse"] = ffp ? "gl_LightSource[0].diffuse" : "Sun.diffuse";
        defines["sunSpecular"] = ffp ? "gl_LightSource[0].specular" : "Sun.specular";
        defines["maxLights"] = std::to_string(getMaxLights());
        defines["maxLightsInScene"] = std::to_string(getMaxLightsInScene());
        defines["lightingModel"] = std::to_string(static_cast<int>(mLightingMethod));
        defines["useUBO"] = std::to_string(mLightingMethod == LightingMethod::SingleUBO);

        return defines;
    }

    void LightManager::setLightingMethod(LightingMethod method)
    {
        mLightingMethod = method;
        switch (method)
        {
        case LightingMethod::FFP:
            mStateSetGenerator = std::make_unique<StateSetGeneratorFFP>();
            break;
        case LightingMethod::SingleUBO:
            mStateSetGenerator = std::make_unique<StateSetGeneratorSingleUBO>();
            break;
        case LightingMethod::PerObjectUniform:
            mStateSetGenerator = std::make_unique<StateSetGeneratorPerObjectUniform>();
            break;
        }
        mStateSetGenerator->mLightManager = this;
    }

    void LightManager::setLightingMask(size_t mask)
    {
        mLightingMask = mask;
    }

    size_t LightManager::getLightingMask() const
    {
        return mLightingMask;
    }

    void LightManager::setStartLight(int start)
    {
        if (!usingFFP()) return;

        mStartLight = start;

        // Set default light state to zero
        // This is necessary because shaders don't respect glDisable(GL_LIGHTX) so in addition to disabling
        // we'll have to set a light state that has no visible effect
        for (int i=start; i<getMaxLights(); ++i)
        {
            osg::ref_ptr<DisableLight> defaultLight (new DisableLight(i));
            getOrCreateStateSet()->setAttributeAndModes(defaultLight, osg::StateAttribute::OFF);
        }
    }

    int LightManager::getStartLight() const
    {
        return mStartLight;
    }

    void LightManager::update(size_t frameNum)
    {   
        getLightData(frameNum).clear();
        mLights.clear();
        mLightsInViewSpace.clear();

        // Do an occasional cleanup for orphaned lights.
        for (int i=0; i<2; ++i)
        {
            if (mStateSetCache[i].size() > 5000) 
                mStateSetCache[i].clear();
        }
    }

    void LightManager::addLight(LightSource* lightSource, const osg::Matrixf& worldMat, size_t frameNum)
    {
        LightSourceTransform l;
        l.mLightSource = lightSource;
        l.mWorldMatrix = worldMat;
        osg::Vec3f pos = osg::Vec3f(worldMat.getTrans().x(), worldMat.getTrans().y(), worldMat.getTrans().z());
        lightSource->getLight(frameNum)->setPosition(osg::Vec4f(pos, 1.f));

        mLights.push_back(l);
    }

    void LightManager::setSunlight(osg::ref_ptr<osg::Light> sun)
    {
        if (usingFFP()) return;

        mSun = sun;
    }

    osg::ref_ptr<osg::Light> LightManager::getSunlight()
    {
        return mSun;
    }

    osg::ref_ptr<SunLightBuffer> LightManager::getSunBuffer()
    {
        return mSunBuffer;
    }

    osg::ref_ptr<osg::StateSet> LightManager::getLightListStateSet(const LightList& lightList, size_t frameNum)
    {
        // possible optimization: return a StateSet containing all requested lights plus some extra lights (if a suitable one exists)
        size_t hash = 0;
        for (size_t i=0; i<lightList.size();++i)
        {
            auto id = lightList[i]->mLightSource->getId();
            hash_combine(hash, id);

            if (getLightingMethod() != LightingMethod::SingleUBO) 
                continue;
            
            if (getLightData(frameNum).find(id) != getLightData(frameNum).end())
                continue;

            int index = getLightData(frameNum).size();
            updateGPUPointLight(index, lightList[i]->mLightSource, frameNum);
            getLightData(frameNum).emplace(lightList[i]->mLightSource->getId(), index);
        }

        auto& stateSetCache = mStateSetCache[frameNum%2];

        auto found = stateSetCache.find(hash);
        if (found != stateSetCache.end())
        {
            mStateSetGenerator->update(found->second, lightList, frameNum);
            return found->second;
        }
        else
        {
            auto stateset = mStateSetGenerator->generate(lightList, frameNum);
            stateSetCache.emplace(hash, stateset);
            return stateset;
        }
        return new osg::StateSet;
    }

    const std::vector<LightManager::LightSourceViewBound>& LightManager::getLightsInViewSpace(osg::Camera *camera, const osg::RefMatrix* viewMatrix, size_t frameNum)
    {
        osg::observer_ptr<osg::Camera> camPtr (camera);
        auto it = mLightsInViewSpace.find(camPtr);

        if (it == mLightsInViewSpace.end())
        {
            it = mLightsInViewSpace.insert(std::make_pair(camPtr, LightSourceViewBoundCollection())).first;
            
            for (const auto& transform : mLights)
            {
                osg::Matrixf worldViewMat = transform.mWorldMatrix * (*viewMatrix);
                
                float radius = transform.mLightSource->getRadius();
                if (getLightingMethod( )!= LightingMethod::FFP)
                    radius *= 0.5;
                osg::BoundingSphere viewBound = osg::BoundingSphere(osg::Vec3f(0,0,0), radius);
                transformBoundingSphere(worldViewMat, viewBound);

                LightSourceViewBound l;
                l.mLightSource = transform.mLightSource;
                l.mViewBound = viewBound;
                it->second.push_back(l);  
            }
        }

        if (getLightingMethod() == LightingMethod::SingleUBO)
        {
            if (it->second.size() > static_cast<size_t>(getMaxLightsInScene()))
            {
                auto sorter = [] (const LightSourceViewBound& left, const LightSourceViewBound& right) {
                    return left.mViewBound.center().length2() - left.mViewBound.radius2() < right.mViewBound.center().length2() - right.mViewBound.radius2();
                };
                std::sort(it->second.begin(), it->second.end(), sorter);
                it->second.erase(it->second.begin() + (getMaxLightsInScene()- 1), it->second.end());
            }
        }

        return it->second;
    }

    void LightManager::updateGPUPointLight(int index, LightSource* lightSource, size_t frameNum)
    {
        auto* light = lightSource->getLight(frameNum);
        mPointBufferMapped[frameNum%2]->setDiffuse(index, light->getDiffuse());
        mPointBufferMapped[frameNum%2]->setAmbient(index, light->getSpecular());
        mPointBufferMapped[frameNum%2]->setAttenuation(index, light->getConstantAttenuation(), light->getLinearAttenuation(), light->getQuadraticAttenuation());
        mPointBufferMapped[frameNum%2]->setRadius(index, lightSource->getRadius() * 0.5);
        mPointBufferMapped[frameNum%2]->setOriginPosition(index, light->getPosition());
    }

    LightSource::LightSource()
        : mRadius(0.f)
    {
        setUpdateCallback(new CollectLightCallback);
        mId = sLightId++;
    }

    LightSource::LightSource(const LightSource &copy, const osg::CopyOp &copyop)
        : osg::Node(copy, copyop)
        , mRadius(copy.mRadius)
    {
        mId = sLightId++;

        for (int i=0; i<2; ++i)
            mLight[i] = new osg::Light(*copy.mLight[i].get(), copyop);
    }

    void LightListCallback::operator()(osg::Node *node, osg::NodeVisitor *nv)
    {
        osgUtil::CullVisitor* cv = static_cast<osgUtil::CullVisitor*>(nv);

        bool pushedState = pushLightState(node, cv);
        traverse(node, nv);
        if (pushedState)
            cv->popStateSet();
    }

    bool LightListCallback::pushLightState(osg::Node *node, osgUtil::CullVisitor *cv)
    {
        if (!mLightManager)
        {
            mLightManager = findLightManager(cv->getNodePath());
            if (!mLightManager)
                return false;
        }

        if (!(cv->getTraversalMask() & mLightManager->getLightingMask()))
            return false;

        // Possible optimizations:
        // - cull list of lights by the camera frustum
        // - organize lights in a quad tree


        // update light list if necessary
        // makes sure we don't update it more than once per frame when rendering with multiple cameras
        if (mLastFrameNumber != cv->getTraversalNumber())
        {

            mLastFrameNumber = cv->getTraversalNumber();

            // Don't use Camera::getViewMatrix, that one might be relative to another camera!
            const osg::RefMatrix* viewMatrix = cv->getCurrentRenderStage()->getInitialViewMatrix();
            const std::vector<LightManager::LightSourceViewBound>& lights = mLightManager->getLightsInViewSpace(cv->getCurrentCamera(), viewMatrix, mLastFrameNumber);
            
            // get the node bounds in view space
            // NB do not node->getBound() * modelView, that would apply the node's transformation twice
            osg::BoundingSphere nodeBound;
            osg::Transform* transform = node->asTransform();
            if (transform)
            {
                for (size_t i=0; i<transform->getNumChildren(); ++i)
                    nodeBound.expandBy(transform->getChild(i)->getBound());
            }
            else
                nodeBound = node->getBound();
            osg::Matrixf mat = *cv->getModelViewMatrix();
            transformBoundingSphere(mat, nodeBound);

            mLightList.clear();
            for (size_t i=0; i<lights.size(); ++i)
            {
                const LightManager::LightSourceViewBound& l = lights[i];

                if (mIgnoredLightSources.count(l.mLightSource))
                    continue;

                if (l.mViewBound.intersects(nodeBound))
                    mLightList.push_back(&l);
            }
        }

        if (!mLightList.empty())
        {
            size_t maxLights = mLightManager->getMaxLights() - mLightManager->getStartLight();

            osg::StateSet* stateset = nullptr;

            if (mLightList.size() > maxLights)
            {
                // remove lights culled by this camera
                LightManager::LightList lightList = mLightList;
                for (auto it = lightList.begin(); it != lightList.end() && lightList.size() > maxLights; )
                {
                    osg::CullStack::CullingStack& stack = cv->getModelViewCullingStack();
                    
                    osg::BoundingSphere bs = (*it)->mViewBound;
                    bs._radius = bs._radius * 2.0;
                    osg::CullingSet& cullingSet = stack.front();
                    if (cullingSet.isCulled(bs))
                    {
                        it = lightList.erase(it);
                        continue;
                    }
                    else
                        ++it;
                }

                if (lightList.size() > maxLights)
                {
                    // sort by proximity to camera, then get rid of furthest away lights
                    std::sort(lightList.begin(), lightList.end(), sortLights);
                    while (lightList.size() > maxLights)
                        lightList.pop_back();
                }
                stateset = mLightManager->getLightListStateSet(lightList, cv->getTraversalNumber());
            }
            else
                stateset = mLightManager->getLightListStateSet(mLightList, cv->getTraversalNumber());

            cv->pushStateSet(stateset);
            return true;
        }
        return false;
    }

}
