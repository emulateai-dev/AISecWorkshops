# Role-play attack

**Role-play** attacks frame the model as a character or scenario to elicit behaviors that a direct refusal might block. PyRIT implements this as an attack type you configure with objectives, targets, and (optionally) converters and scorers.

**Concepts**

- Objective text drives what the attack optimizes for.
- Chat targets preserve **dialogue state** across turns when the attack requires it.

**Workshop use**

This tab explains the pattern; **Run for me** may remain a stub until a dedicated runner is wired. Use the coach’s **execute_python** only with benign objectives on authorized endpoints.

**Official docs**

- [Role-play attack](https://azure.github.io/PyRIT/code/executor/attack/role-play-attack/)
