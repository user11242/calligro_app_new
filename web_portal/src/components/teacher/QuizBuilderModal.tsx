import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { X, Plus, Trash2, CheckCircle2, GripVertical, AlertCircle } from 'lucide-react';
import { useTranslation } from '@/hooks/useTranslation';

export type QuizQuestion = {
  id: string;
  text: string;
  options: string[];
  correctOptionIndex: number;
};

interface QuizBuilderModalProps {
  isOpen: boolean;
  onClose: () => void;
  initialQuestions: QuizQuestion[];
  onSave: (questions: QuizQuestion[]) => void;
}

export default function QuizBuilderModal({ isOpen, onClose, initialQuestions, onSave }: QuizBuilderModalProps) {
  const { t } = useTranslation();
  const [questions, setQuestions] = useState<QuizQuestion[]>([]);
  const [activeQuestionId, setActiveQuestionId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (isOpen) {
      if (initialQuestions && initialQuestions.length > 0) {
        setQuestions(JSON.parse(JSON.stringify(initialQuestions)));
        setActiveQuestionId(initialQuestions[0].id);
      } else {
        const newQ = createNewQuestion();
        setQuestions([newQ]);
        setActiveQuestionId(newQ.id);
      }
      setError(null);
    }
  }, [isOpen, initialQuestions]);

  const createNewQuestion = (): QuizQuestion => {
    return {
      id: `q-${Date.now()}`,
      text: '',
      options: ['', ''], // Default 2 options
      correctOptionIndex: 0
    };
  };

  const handleAddQuestion = () => {
    const newQ = createNewQuestion();
    setQuestions([...questions, newQ]);
    setActiveQuestionId(newQ.id);
  };

  const handleDeleteQuestion = (id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    if (questions.length === 1) return; // Prevent deleting the last question
    const updated = questions.filter(q => q.id !== id);
    setQuestions(updated);
    if (activeQuestionId === id) {
      setActiveQuestionId(updated[0].id);
    }
  };

  const updateActiveQuestion = (updates: Partial<QuizQuestion>) => {
    setQuestions(questions.map(q => 
      q.id === activeQuestionId ? { ...q, ...updates } : q
    ));
  };

  const handleAddOption = () => {
    const activeQ = questions.find(q => q.id === activeQuestionId);
    if (!activeQ || activeQ.options.length >= 6) return;
    updateActiveQuestion({ options: [...activeQ.options, ''] });
  };

  const handleUpdateOption = (index: number, value: string) => {
    const activeQ = questions.find(q => q.id === activeQuestionId);
    if (!activeQ) return;
    const newOptions = [...activeQ.options];
    newOptions[index] = value;
    updateActiveQuestion({ options: newOptions });
  };

  const handleDeleteOption = (index: number) => {
    const activeQ = questions.find(q => q.id === activeQuestionId);
    if (!activeQ || activeQ.options.length <= 2) return; // Min 2 options
    const newOptions = activeQ.options.filter((_, i) => i !== index);
    
    let newCorrectIndex = activeQ.correctOptionIndex;
    if (newCorrectIndex === index) {
      newCorrectIndex = 0; // Reset if the correct answer is deleted
    } else if (newCorrectIndex > index) {
      newCorrectIndex -= 1; // Shift index if deleted option was before it
    }
    
    updateActiveQuestion({ options: newOptions, correctOptionIndex: newCorrectIndex });
  };

  const handleSave = () => {
    // Validate
    for (let i = 0; i < questions.length; i++) {
      const q = questions[i];
      if (!q.text.trim()) {
        setError(t('teacher.courses.edit.quiz.error.missing_text').replace('{q}', String(i + 1)));
        setActiveQuestionId(q.id);
        return;
      }
      for (let j = 0; j < q.options.length; j++) {
        if (!q.options[j].trim()) {
          setError(t('teacher.courses.edit.quiz.error.missing_option').replace('{q}', String(i + 1)).replace('{o}', String(j + 1)));
          setActiveQuestionId(q.id);
          return;
        }
      }
    }
    
    setError(null);
    onSave(questions);
    onClose();
  };

  const activeQ = questions.find(q => q.id === activeQuestionId) || questions[0];

  if (!isOpen || !activeQ) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/80 backdrop-blur-sm p-4">
      <motion.div 
        initial={{ opacity: 0, scale: 0.95, y: 20 }}
        animate={{ opacity: 1, scale: 1, y: 0 }}
        exit={{ opacity: 0, scale: 0.95, y: 20 }}
        className="bg-[#1C1F26] border border-white/10 rounded-2xl w-full max-w-5xl h-[85vh] flex flex-col shadow-2xl overflow-hidden"
      >
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-white/5 bg-[#16181D]">
          <div>
            <h2 className="text-xl font-bold text-white">{t('teacher.courses.edit.quiz.builder_title')}</h2>
            <p className="text-sm text-white/50 mt-1">{t('teacher.courses.edit.quiz.builder_subtitle')}</p>
          </div>
          <button 
            onClick={onClose}
            className="p-2 text-white/40 hover:text-white hover:bg-white/10 rounded-lg transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Content */}
        <div className="flex flex-1 overflow-hidden">
          
          {/* Left Sidebar: Question List */}
          <div className="w-64 border-r border-white/5 bg-[#13151A] flex flex-col overflow-y-auto" dir="ltr">
            <div className="p-4">
              <h3 className="text-xs font-bold tracking-widest text-white/40 uppercase mb-4">{t('teacher.courses.edit.quiz.questions')}</h3>
              <div className="space-y-2">
                {questions.map((q, i) => (
                  <div 
                    key={q.id}
                    onClick={() => setActiveQuestionId(q.id)}
                    className={`
                      w-full flex items-center gap-3 px-3 py-3 rounded-xl cursor-pointer transition-all group
                      ${activeQuestionId === q.id 
                        ? 'bg-[#D4AF37]/10 border border-[#D4AF37]/30 text-white' 
                        : 'bg-white/5 border border-transparent text-white/60 hover:bg-white/10 hover:text-white'}
                    `}
                  >
                    <div className={`w-6 h-6 rounded-md flex items-center justify-center text-xs font-bold shrink-0
                      ${activeQuestionId === q.id ? 'bg-[#D4AF37] text-black' : 'bg-white/10 text-white/60'}
                    `}>
                      {i + 1}
                    </div>
                    <span className="text-sm font-medium truncate flex-1 rtl:text-right" dir="auto">
                      {q.text || t('teacher.courses.edit.quiz.empty_question')}
                    </span>
                    {questions.length > 1 && (
                      <button 
                        onClick={(e) => handleDeleteQuestion(q.id, e)}
                        className="opacity-0 group-hover:opacity-100 p-1.5 text-white/40 hover:text-red-400 hover:bg-red-400/10 rounded-lg transition-all"
                      >
                        <Trash2 className="w-3.5 h-3.5" />
                      </button>
                    )}
                  </div>
                ))}
              </div>

              <button 
                onClick={handleAddQuestion}
                className="mt-4 flex items-center justify-center gap-2 w-full py-3 rounded-xl border border-dashed border-white/20 text-white/60 hover:text-white hover:border-white/40 hover:bg-white/5 transition-all text-sm font-medium"
              >
                <Plus className="w-4 h-4" /> {t('teacher.courses.edit.quiz.add_question')}
              </button>
            </div>
          </div>

          {/* Right Area: Question Editor */}
          <div className="flex-1 flex flex-col overflow-y-auto bg-[#1C1F26] relative" dir="auto">
            {error && (
              <div className="absolute top-0 left-0 right-0 p-3 bg-red-500/10 border-b border-red-500/20 text-red-400 text-sm font-medium flex items-center justify-center gap-2 z-10">
                <AlertCircle className="w-4 h-4" /> {error}
              </div>
            )}
            
            <div className="p-8 max-w-3xl mx-auto w-full space-y-8 mt-4">
              
              {/* Question Text */}
              <div className="space-y-3">
                <label className="text-sm font-medium text-white/80">{t('teacher.courses.edit.quiz.question_text_label')}</label>
                <textarea
                  value={activeQ.text}
                  onChange={(e) => updateActiveQuestion({ text: e.target.value })}
                  placeholder={t('teacher.courses.edit.quiz.question_text_placeholder')}
                  rows={3}
                  className="w-full bg-[#13151A] border border-white/10 rounded-xl px-5 py-4 text-white placeholder-white/40 outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] transition-all resize-y text-lg"
                />
              </div>

              {/* Options */}
              <div className="space-y-4">
                <div className="flex items-center justify-between">
                  <div>
                    <h3 className="text-sm font-medium text-white/80">{t('teacher.courses.edit.quiz.options_label')}</h3>
                    <p className="text-xs text-white/40 mt-1">{t('teacher.courses.edit.quiz.options_desc')}</p>
                  </div>
                </div>

                <div className="space-y-3">
                  <AnimatePresence>
                    {activeQ.options.map((opt, i) => {
                      const isCorrect = activeQ.correctOptionIndex === i;
                      return (
                        <motion.div 
                          key={i}
                          initial={{ opacity: 0, y: 10 }}
                          animate={{ opacity: 1, y: 0 }}
                          exit={{ opacity: 0, scale: 0.95 }}
                          className={`flex items-center gap-3 p-2 rounded-xl border transition-all ${
                            isCorrect 
                              ? 'bg-green-500/5 border-green-500/30 shadow-[0_0_15px_rgba(34,197,94,0.05)]' 
                              : 'bg-[#13151A] border-white/5 focus-within:border-white/20'
                          }`}
                        >
                          {/* Radio Button */}
                          <div 
                            onClick={() => updateActiveQuestion({ correctOptionIndex: i })}
                            className={`w-6 h-6 rounded-full flex items-center justify-center cursor-pointer ml-2 shrink-0 transition-all ${
                              isCorrect 
                                ? 'bg-green-500 text-black' 
                                : 'bg-white/10 border border-white/20 hover:border-white/40'
                            }`}
                          >
                            {isCorrect && <CheckCircle2 className="w-4 h-4" />}
                          </div>

                          {/* Input */}
                          <input
                            type="text"
                            value={opt}
                            onChange={(e) => handleUpdateOption(i, e.target.value)}
                            placeholder={`${t('teacher.courses.edit.quiz.option_placeholder')} ${i + 1}`}
                            className={`flex-1 bg-transparent outline-none py-2 text-sm transition-colors ${
                              isCorrect ? 'text-green-50 font-medium' : 'text-white'
                            }`}
                          />

                          {/* Delete */}
                          {activeQ.options.length > 2 && (
                            <button 
                              onClick={() => handleDeleteOption(i)}
                              className="p-2 text-white/20 hover:text-red-400 hover:bg-red-400/10 rounded-lg transition-all shrink-0 mr-1"
                            >
                              <Trash2 className="w-4 h-4" />
                            </button>
                          )}
                        </motion.div>
                      );
                    })}
                  </AnimatePresence>
                </div>

                {/* Add Option Button */}
                {activeQ.options.length < 6 && (
                  <button 
                    onClick={handleAddOption}
                    className="flex items-center gap-2 text-sm text-[#D4AF37] font-medium hover:text-white transition-colors mt-2"
                  >
                    <Plus className="w-4 h-4" /> {t('teacher.courses.edit.quiz.add_option')}
                  </button>
                )}
              </div>
            </div>
          </div>
        </div>

        {/* Footer */}
        <div className="p-4 border-t border-white/5 bg-[#16181D] flex items-center justify-end gap-3 shrink-0">
          <button 
            onClick={onClose}
            className="px-6 py-2.5 rounded-xl border border-white/10 text-white/60 hover:text-white hover:bg-white/5 transition-all text-sm font-medium"
          >
            {t('teacher.courses.edit.quiz.cancel')}
          </button>
          <button 
            onClick={handleSave}
            className="px-8 py-2.5 rounded-xl bg-[#D4AF37] text-black hover:bg-[#E0C17E] transition-all text-sm font-bold shadow-lg shadow-[#D4AF37]/20"
          >
            {t('teacher.courses.edit.quiz.save')}
          </button>
        </div>

      </motion.div>
    </div>
  );
}
