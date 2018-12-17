#pragma once
#include "Physika_Framework/Framework/Module.h"

namespace Physika
{
class Field;

class ConstraintModule : public Module
{
public:
	ConstraintModule();
	~ConstraintModule() override;

	//interface for data initialization, must be called before execution
	virtual bool connectPosition(std::shared_ptr<Field>& pos) { return true; }
	virtual bool connectVelocity(std::shared_ptr<Field>& vel) { return true; }

	void setPositionID(FieldID id) { m_posID = id; }
	void setVelocityID(FieldID id) { m_velID = id; }

	virtual bool constrain() { return true; }

	std::string getModuleType() override { return "ConstraintModule"; }
protected:
	FieldID m_posID;
	FieldID m_velID;
};
}
